Class {
	#name : #TtObjectEncoder,
	#superclass : #Object,
	#instVars : [
		'writeStream',
		'stringTable',
		'symbolTable'
	],
	#category : #'TinyTools-Core'
}

{ #category : #private }
TtObjectEncoder class >> appendBytes: aByteArray to: aFileName [

	"Append the specified bytes to the specified file"

	| stream |

	stream := (File named: aFileName)
		openForAppend.

	stream
		nextPutAll: aByteArray ;
		close
]

{ #category : #'public api' }
TtObjectEncoder class >> appendClass: aClass selectMethods: aBlock to: aFileName [

	| bytes |

	bytes := self new
		encodeClass: aClass selectMethods: aBlock ;
		bytes.

	self appendBytes: bytes to: aFileName
]

{ #category : #'public api' }
TtObjectEncoder class >> appendClass: aClass to: aFileName [

	self appendClass: aClass selectMethods: [ :each | true ] to: aFileName
]

{ #category : #'public api' }
TtObjectEncoder class >> appendMethod: aCompiledMethod to: aFileName [

	| bytes |

	bytes := self new
		encodeCompiledMethod: aCompiledMethod ;
		bytes.

	self appendBytes: bytes to: aFileName
]

{ #category : #accessing }
TtObjectEncoder class >> knownGlobals [

	^ { Smalltalk . Processor }
]

{ #category : #utilities }
TtObjectEncoder class >> minimalByteSizeFor: anInteger [

	"Answer the minimal number of bytes needed for 2's complement representation of anInteger"

	"Handle special case where anInteger is zero"
	anInteger = 0
		ifTrue: [ ^ 0 ].

	"The index of the following literal array of masks represents the number of bytes needed.
	Answer the first matching mask. A mask matches all meaningless bits (1's for negative
	and 0's for positive integers in 2's complement representation, including the high bit
	for the sign)."
	^ #(
		16rffffff80
		16rffff8000
		16rff800000
		16r80000000
	) findFirst: (anInteger negative
		ifTrue: [ [ :mask | (anInteger bitAnd: mask) = mask ] ]
		ifFalse: [ [ :mask | (anInteger bitAnd: mask) = 0 ] ])
]

{ #category : #'public api' }
TtObjectEncoder class >> writeClass: aClass selectMethods: aBlock to: aFileName [

	File deleteFile: aFileName.

	self appendClass: aClass selectMethods: aBlock to: aFileName
]

{ #category : #'public api' }
TtObjectEncoder class >> writeClass: aClass to: aFileName [

	self writeClass: aClass selectMethods: [ :each | true ] to: aFileName
]

{ #category : #'public api' }
TtObjectEncoder class >> writeMethod: aCompiledMethod to: aFileName [

	File deleteFile: aFileName.

	self appendMethod: aCompiledMethod to: aFileName
]

{ #category : #writing }
TtObjectEncoder >> basicWriteString: aString [

	"Write aString (can be Symbol) using UTF-8"

	self writeLength: aString size.
	aString do: [ :char | self writeUTF8CodePoint: char asUnicode ]
]

{ #category : #writing }
TtObjectEncoder >> basicWriteString: aString usingTable: aCollection [

	"Write aString (can be a Symbol) using the specified table (cache)"

	| index |

	index := aCollection
		indexOf: aString
		ifAbsent: [
			"We have max 11 bits of table space (2 raisedTo: 11), see #basicWriteStringIndex: for an explanation"
			aCollection size < 2048
				ifTrue: [ aCollection add: aString ].
			^ self basicWriteString: aString ].

	"Since Smalltalk indices always start at 1 subtract 1 to use 0 value as well"
	self basicWriteStringIndex: index - 1
]

{ #category : #writing }
TtObjectEncoder >> basicWriteStringIndex: anInteger [

	"Write the specified index (into either the String or Symbol table).
	Assume anInteger is max 11 bits big.

	Use a 3 byte encoding which is similar to regular Strings, but has an
	invalid UTF-8 encoding to trigger this special behavior. This prevents
	additional typing information to be needed in the different locations
	where Strings and Symbols are used.

	First byte contains the length 2 (for 2 additional bytes).
	Second byte contains invalid UTF-8 marker and 3 index bits: 11111xxx
	Third byte contains remaining index bits: yyyyyyyy
	Index = 02r<xxxyyyyyyyy>"

	self writeLength: 2.
	writeStream
		nextPut: 16rf8 + (anInteger bitShift: -8) ;
		nextPut: (anInteger bitAnd: 16rff)
]

{ #category : #accessing }
TtObjectEncoder >> bytes [

	^ writeStream contents
]

{ #category : #encoding }
TtObjectEncoder >> encode: anObject [

	"Encode the specified Object"

	anObject ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodeAdditionalMethodState: anAdditionalMethodState [

	writeStream nextPut: 19.

	self writeSymbol: anAdditionalMethodState selector.
	self writeArray: anAdditionalMethodState pragmas asArray
]

{ #category : #encoding }
TtObjectEncoder >> encodeArray: anArray [

	"Encode the Array by writing its length and encoding the individuel Array elements"

	writeStream nextPut: 15.
	self writeArray: anArray
]

{ #category : #encoding }
TtObjectEncoder >> encodeAssociation: anAssociation [

	"Encode the specified Association, assuming this is part of a CompiledMethod"

	| key value |

	key := anAssociation key.
	value := anAssociation value.

	"Association is class reference"
	(key isSymbol and: [ value isClass and: [ key = value name ] ])
		ifTrue: [ ^ self encodeClassReference: value ].

	"Association is metaclass reference"
	(key isNil and: [ value isClass and: [ value isMeta ] ])
		ifTrue: [ ^ self encodeMetaclassReference: value ].

	"Regular Association"
	writeStream nextPut: 16.
	key ttEncodeWith: self.
	value ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodeCharacter: aCharacter [

	"Encode aCharacter using its Unicode value and write using UTF-8."

	writeStream nextPut: 4.
	self writeUTF8CodePoint: aCharacter asUnicode
]

{ #category : #encoding }
TtObjectEncoder >> encodeClass: aClass [

	"Encode the specified class with all its instance and class methods"

	self encodeClass: aClass selectMethods: [ :each | true ]
]

{ #category : #encoding }
TtObjectEncoder >> encodeClass: aClass selectMethods: aBlock [

	"Encode aClass using its name, the superclass' name, instance and class variable names and
	th instance and class methods which evaluate to true for the specified selection block.
	Classes with SharedPools, that is pool dictionaries, are currently not supported."

	aClass sharedPoolNames
		ifNotEmpty: [ self error: 'Classes with pool dictionaries are not supported yet' ]. 	

	writeStream nextPut: 25.

	"Write class and superclass names"
	self writeSymbol: aClass name.
	self writeSymbol: aClass superclass name.

	"Write instance variable and class variable names (name collections might be Set or OrderedCollection)"
	self writeArray: aClass instVarNames asArray.
	self writeArray: aClass classVarNames asArray.

	"Write both instance and class methods"
	self writeArray: (aClass methodDictionary asArray select: aBlock).
	self writeArray: (aClass class methodDictionary asArray select: aBlock)
]

{ #category : #encoding }
TtObjectEncoder >> encodeClassReference: aClass [

	writeStream nextPut: 21.
	self writeSymbol: aClass name
]

{ #category : #encoding }
TtObjectEncoder >> encodeClassVariable: aClassVariable [

	"Encode aClassVariable"

	writeStream nextPut: 23.
	self writeSymbol: aClassVariable key
]

{ #category : #encoding }
TtObjectEncoder >> encodeCompiledBlock: aCompiledBlock [

	"Encode aCompiledBlock based on the block's header, bytecode and literals.
	This will not include the Method the block is part of."

	| initialPC endPC |

	writeStream nextPut: 29.

	"Write header"
	self writeUInt32: (self normalizeHeader: aCompiledBlock header).

	"Write bytecode (without creating intermediate collection)"
	initialPC := aCompiledBlock initialPC.
	endPC := aCompiledBlock endPC.
	self writeLength: endPC - initialPC + 1.
	
	initialPC to: endPC do: [ :byteIndex | writeStream nextPut: (aCompiledBlock byteAt: byteIndex) ].

	"Write literals (excl. outerCode which is positioned at index 'numLiterals', otherwise we get into infinite loop)"
	1 to: aCompiledBlock numLiterals - 1 do: [ :literalIndex |
		(aCompiledBlock literalAt: literalIndex) ttEncodeWith: self ]
]

{ #category : #encoding }
TtObjectEncoder >> encodeCompiledMethod: aCompiledMethod [

	"Encode aCompiledMethod based on the method's header, bytecode and literals.
	This will include the Class the method is installed in."

	| initialPC endPC |

	writeStream nextPut: 18.

	"Write header"
	self writeUInt32: (self normalizeHeader: aCompiledMethod header).

	"Write bytecode (without creating intermediate collection)"
	initialPC := aCompiledMethod initialPC.
	endPC := aCompiledMethod endPC.
	self writeLength: endPC - initialPC + 1.
	
	initialPC to: endPC do: [ :byteIndex | writeStream nextPut: (aCompiledMethod byteAt: byteIndex) ].

	"Write literals"
	1 to: aCompiledMethod numLiterals do: [ :literalIndex |
		(aCompiledMethod literalAt: literalIndex) ttEncodeWith: self ]
]

{ #category : #encoding }
TtObjectEncoder >> encodeConstantBlockClosure: aConstantBlockClosure [

	"Encode aConstantBlockClosure using its number of arguments
	and the literal representing its constant value"

	writeStream nextPut: 31.

	self writeLength: aConstantBlockClosure numArgs.

	aConstantBlockClosure literal ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodeDictionary: aDictionary [

	"Encode the Dictionary as an Array of Associations"

	writeStream nextPut: 17.
	self writeArray: aDictionary associations
]

{ #category : #encoding }
TtObjectEncoder >> encodeFalse [

	writeStream nextPut: 3
]

{ #category : #encoding }
TtObjectEncoder >> encodeFloat: aFloat [

	"Encode aFloat using its 64-bit (double precision) IEEE-754 representation"

	"Write float type and both 32-bit words constituting the 64-bit float"
	writeStream nextPut: 14.
	self
		writeUInt32: (aFloat basicAt: 1) ;
		writeUInt32: (aFloat basicAt: 2)
]

{ #category : #encoding }
TtObjectEncoder >> encodeGlobalVariable: aGlobalVariable [

	"Encode aGlobalVariable (only if it refers to a known global or class)"

	((self class knownGlobals includes: aGlobalVariable value) or: [ aGlobalVariable value isClass ])
		ifFalse: [ self error: 'Only classes are supported as global variables' ].

	writeStream nextPut: 24.
	self writeSymbol: aGlobalVariable key
]

{ #category : #encoding }
TtObjectEncoder >> encodeInteger: anInteger [

	"Encode anInteger in as few bytes as possible, based on 2's complement representation.
	If the representation requires more than 4 bytes, use regular encoding."

	anInteger < -16r80000000
		ifTrue: [ self encodeLargeNegativeInteger: anInteger ]
		ifFalse: [
			anInteger >= 16r80000000
				ifTrue: [ self encodeLargePositiveInteger: anInteger ]
				ifFalse: [ self writeInteger: anInteger forBaseType: 7 ] ]
]

{ #category : #encoding }
TtObjectEncoder >> encodeLargeNegativeInteger: anInteger [

	writeStream nextPut: 13.
	self writeLargePositiveInteger: anInteger negated
]

{ #category : #encoding }
TtObjectEncoder >> encodeLargePositiveInteger: anInteger [

	writeStream nextPut: 12.
	self writeLargePositiveInteger: anInteger
]

{ #category : #encoding }
TtObjectEncoder >> encodeMessage: aMessage [

	"Encode aMessage using its selector and arguments (lookupClass is ignored).
	The selector and all arguments should be encodable themselves."

	writeStream nextPut: 27.

	"Write selector (a Symbol)"
	self writeSymbol: aMessage selector.

	"Encode arguments (either nil or Array)"
	aMessage arguments ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodeMessageSend: aMessageSend [

	"Encode aMessageSend using its receiver, selector and arguments.
	The MessageSend's receiver is assumed to have been replaced by some encodable value
	since most regular Objects will not be encodable.
	Also the selector and all arguments should be encodable themselves."

	writeStream nextPut: 26.

	"Encode receiver"
	aMessageSend receiver ttEncodeWith: self.

	"Write selector (a Symbol)"
	self writeSymbol: aMessageSend selector.

	"Encode arguments (either nil or Array)"
	aMessageSend arguments ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodeMetaclassReference: aClass [

	writeStream nextPut: 22.
	self writeSymbol: aClass instanceSide name
]

{ #category : #encoding }
TtObjectEncoder >> encodeNil [

	writeStream nextPut: 1
]

{ #category : #encoding }
TtObjectEncoder >> encodePoint: aPoint [

	"Encode aPoint using its x and y value (allowing non integers as well)"

	writeStream nextPut: 28.

	aPoint x ttEncodeWith: self.
	aPoint y ttEncodeWith: self
]

{ #category : #encoding }
TtObjectEncoder >> encodePragma: aPragma [

	writeStream nextPut: 20.

	self writeSymbol: aPragma selector.
	self writeArray: aPragma arguments asArray
]

{ #category : #encoding }
TtObjectEncoder >> encodeString: aString [

	writeStream nextPut: 6.
	self writeString: aString
]

{ #category : #encoding }
TtObjectEncoder >> encodeSymbol: aSymbol [

	writeStream nextPut: 5.
	self writeSymbol: aSymbol
]

{ #category : #encoding }
TtObjectEncoder >> encodeTrue [

	writeStream nextPut: 2
]

{ #category : #initialization }
TtObjectEncoder >> initialize [

	super initialize.

	writeStream := WriteStream on: (ByteArray new: 256).

	"Implementation: The stringTable is lazy initialized"
	symbolTable := OrderedCollection new
]

{ #category : #accessing }
TtObjectEncoder >> normalizeHeader: header [

	"Normalize the header value of CompiledCode. (See class comment of CompiledCode)

	Implementation:
	Reposition the sign flag used to indicate secondary bytecode set being used.
	The sign position is moved to an unused 31st bit in the header (allowing the
	integer to remain unsigned."

	^ header < 0
		ifTrue: [ (header - SmallInteger minVal) bitOr: 16r40000000 ]
		ifFalse: [ header ]
]

{ #category : #writing }
TtObjectEncoder >> writeArray: anArray [

	self writeLength: anArray size.
	anArray do: [ :each | each ttEncodeWith: self ]
]

{ #category : #writing }
TtObjectEncoder >> writeInteger: anInteger forBaseType: baseType [

	"Write anInteger in as few bytes as possible using little endian (least significant byte first) order.
	If the representation requires more than 4 bytes, an error is thrown.
	The specified base type is used for value 0, base type + 1 is used for 1 byte representation, base type + 2 is used for 2 bytes. etc."

	| byteSize remainingValue |

	"Write type based on length of integer representation"
	byteSize := self class minimalByteSizeFor: anInteger.
	writeStream nextPut: baseType + byteSize.

	"Create positive integer with same bit representation as anInteger.
	(for negative integers this will require 5 bytes, but this fifth byte won't be written)"
	remainingValue := anInteger negative
		ifTrue: [ (anInteger + 1) negated bitXor: 16rffffffff ]
		ifFalse: [ anInteger ].

	"Write integer in little endian order"
	byteSize timesRepeat: [
		writeStream nextPut: (remainingValue bitAnd: 16rff).
		remainingValue := remainingValue bitShift: -8 ]
]

{ #category : #writing }
TtObjectEncoder >> writeLargePositiveInteger: anInteger [

	"Write anInteger as bytes in little endian (least significant byte first) order.
	anInteger is assumed to be positive. anInteger might actually be a SmallInteger (requiring more than 4 bytes).
	Only allow integers of up to 16rffff (ie 65535) bytes long. This means the maximum supported value is:
	[[[(2 raisedToInteger: 16rffff * 8) - 1]]]"

	| byteSize remainingValue |

	"Start with shortest representation of anInteger"
	remainingValue := anInteger normalize.

	"Write size in bytes"
	byteSize := remainingValue = 0
		ifTrue: [ 0 ]
		ifFalse: [ remainingValue byteSize ].
	self writeLength: byteSize.

	"Write bytes in little endian order"
	byteSize timesRepeat: [
		writeStream nextPut: (remainingValue bitAnd: 16rff).
		remainingValue := remainingValue bitShift: -8 ]
]

{ #category : #writing }
TtObjectEncoder >> writeLength: anInteger [

	"Write a length value using a byte encoding where one 1 bit is designated to mark the final byte.
	Length should be either 0 or positive.
	anInteger is stored in a little endian (least significant byte first) order."

	| remainingValue byte |

	anInteger negative
		ifTrue: [ self error: 'A negative length is not supported' ].

	"Special case 0, since algorithm below assumes a value larger than 0"
	anInteger = 0
		ifTrue: [
			writeStream nextPut: 16r80.	"Include end marker"
			^ self ].

	"Write 7 bits of the length at a time (little endian order)"
	remainingValue := anInteger.
	[ remainingValue > 0 ]
		whileTrue: [

			"Extract next 7 bits"
			byte := remainingValue bitAnd: 16r7f.
			remainingValue := remainingValue bitShift: -7.

			"Write byte"
			writeStream nextPut: (byte bitOr: (remainingValue = 0 ifTrue: [ 16r80 ] ifFalse: [ 16r00 ])) ]
]

{ #category : #writing }
TtObjectEncoder >> writeString: aString [

	"Write aString (should not be a Symbol)"

	self basicWriteString: aString usingTable: (stringTable ifNil: [ stringTable := OrderedCollection new ])
]

{ #category : #writing }
TtObjectEncoder >> writeSymbol: aSymbol [

	"Write aSymbol (should not be a String)"

	self basicWriteString: aSymbol usingTable: symbolTable
]

{ #category : #writing }
TtObjectEncoder >> writeUInt32: uint32 [

	"Write uint32 using little endian (least significant byte first) order"

	writeStream
		nextPut: (uint32 bitAnd: 16rff) ;
		nextPut: ((uint32 bitShift: -8) bitAnd: 16rff) ;
		nextPut: ((uint32 bitShift: -16) bitAnd: 16rff) ;
		nextPut: ((uint32 bitShift: -24) bitAnd: 16rff)
]

{ #category : #writing }
TtObjectEncoder >> writeUTF8CodePoint: unicode [

	"Write the character specified by the Unicode codepoint using UTF-8.
	See also https://en.wikipedia.org/wiki/UTF-8"

	unicode <= 16r7f
		ifTrue: [ writeStream nextPut: unicode ]
		ifFalse: [

			| bytesToWrite encodingBits bitShift |

			"Decide how many additional bytes to write and encoding of first byte"
			unicode <= 16r7ff
				ifTrue: [ bytesToWrite := 1. encodingBits := 16rc0 ]		"Encoding 110xxxxxx for 2-byte UTF-8 character"
				ifFalse: [
					unicode <= 16rffff
						ifTrue: [ bytesToWrite := 2. encodingBits := 16re0 ]		"Encoding 1110xxxx for 3-byte UTF-8 character"
						ifFalse: [
							unicode <= 16r10ffff
								ifTrue: [ bytesToWrite := 3. encodingBits := 16rf0 ]		"Encoding 11110xxx for 4-byte UTF-8 character"
								ifFalse: [ self error: 'Invalid unicode codepoint' ] ] ].

			"Write first byte (with special encoding)"
			bitShift := bytesToWrite * -6.
			writeStream nextPut: ((unicode bitShift: bitShift) bitOr: encodingBits).

			"Write additional bytes (with continuation encoding 10xxxxxx)"
			bytesToWrite timesRepeat: [
				bitShift := bitShift + 6.
				writeStream nextPut: (((unicode bitShift: bitShift) bitAnd: 16r3f) bitOr: 16r80) ] ]
]
