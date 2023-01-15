Class {
	#name : #TtInspector,
	#superclass : #Object,
	#category : #'TinyTools-Core'
}

{ #category : #private }
TtInspector class >> allClassAssociationsDo: aBlock [

	"Evaluate the specified Block for all Associations name -> class.
	An (optional) second argument is given to the Block as argument with the following value:
		#both		- class is known as global
		#class		- class defined as Metaclass instance
		#global	- class defined as global

	If two versions of a Class are installed and an instance is still in the image, both classes
	will be present in the image (one reachable through the Smalltalk globals). A class might also
	be uninstalled, but still exist because of a reference to the class.
	Some classes are also stored as global. Class Association is also stored as global ClassVariable
	and will therefore only be recognized as a global (under this name)."

	| classInstances globals index1 index2 |

	"Classes based on instance of Metaclass"
	classInstances := OrderedCollection new.
	Metaclass allInstancesDo: [ :each | each instanceSide ifNotNil: [ :aClass | classInstances add: (aClass name -> aClass) ] ].

	"Classes based on Smalltalk global dictionary"
	globals := OrderedCollection new.
	Smalltalk globals keysAndValuesDo: [ :key :value | value isClass ifTrue: [ globals add: (key -> value) ] ].

	"Sort both collections (for better comparison)"
	classInstances sort: [ :a :b | a key < b key ].
	globals sort: [ :a :b | a key < b key ].

	"Iterate all classes"
	index1 := 1.
	index2 := 1.
	[ index1 <= classInstances size or: [ index2 <= globals size ] ] whileTrue: [
		| classAssoc1 classAssoc2 |
		classAssoc1 := classInstances at: index1 ifAbsent: [ nil ].
		classAssoc2 := globals at: index2 ifAbsent: [ nil ].
		classAssoc1 value == classAssoc2 value
			ifTrue: [
				"Class is Metaclass instance AND known as global"
				aBlock cull: classAssoc1 cull: #both.

				"Iterate all Metaclass instances with same name"
				[ (classAssoc1 := classInstances at: (index1 := index1 + 1) ifAbsent: [ nil ]) isNotNil and: [ classAssoc1 key == classAssoc2 key ] ] whileTrue: [
					aBlock cull: classAssoc1 cull: #class ].				
				index2 := index2 + 1 ]
			ifFalse: [
				classAssoc1
					ifNotNil: [
						classAssoc2
							ifNotNil: [
								classAssoc1 key == classAssoc2 key
									ifTrue: [
										"Class has both Metaclass instance AND global, but they differ"
										aBlock cull: classAssoc1 cull: #class.

										"Iterate all Metaclass instances with same name"
										[ (classAssoc1 := classInstances at: (index1 := index1 + 1) ifAbsent: [ nil ]) isNotNil and: [ classAssoc1 key == classAssoc2 key ] ] whileTrue: [
											aBlock cull: classAssoc1 cull: (classAssoc1 value == classAssoc2 value ifTrue: [ #both ] ifFalse: [ #class ]) ].				

										aBlock cull: classAssoc2 cull: #global.
										index2 := index2 + 1 ]
									ifFalse: [
										classAssoc1 key < classAssoc2 key
											ifTrue: [
												"Only a Metaclass instance exists"
												aBlock cull: classAssoc1 cull: #class.
												index1 := index1 + 1 ]
											ifFalse: [
												"Only a global exists"
												aBlock cull: classAssoc2 cull: #global.
												index2 := index2 + 1 ] ] ]
							ifNil: [
								"No more globals left"
								aBlock cull: classAssoc1 cull: #class.
								index1 := index1 + 1 ] ]
					ifNil: [
						classAssoc2
							ifNotNil: [
								"No more Metaclass instances left"
								aBlock cull: classAssoc2 cull: #global.
								index2 := index2 + 1 ] ] ] ]
]

{ #category : #'public api' }
TtInspector class >> showClasses [

	"Show all classes present in the tiny image"

	self showClassesAndMethods: false
]

{ #category : #'public api' }
TtInspector class >> showClassesAndMethods [

	"Show all classes and all their methods present in the tiny image"

	self showClassesAndMethods: true
]

{ #category : #private }
TtInspector class >> showClassesAndMethods: aBoolean [

	"Show all classes and (if specified) all their methods
	present in the tiny image.
	Classes which are only present as a Metaclass instance or
	only registered in the globals are shown with a remark.
	Multiple classes can exist with the same name. All will
	be shown (and therefore some will have a remark, since
	the globals can't contain multiple classes with the same name)."

	| typeDescription |

	"Remark for different types"
	typeDescription := Dictionary new
		at: #both put: '' ;
		at: #class put: ' (Metaclass instance)' ;
		at: #global put: ' (defined as global)' ;
		yourself.

	self allClassAssociationsDo: [ :each :type |
		self crTrace: each key, (typeDescription at: type ifAbsent: [ ' (unknown)' ]).
		aBoolean
			ifTrue: [ self showMethodsFor: each value ] ]
]

{ #category : #'public api' }
TtInspector class >> showMethodsFor: aClass [

	"Show methods (both class side and instance side) for the specified Class"

	"Class side methods"
	aClass class selectors do: [ :each |
		self crTrace: aClass name, ' class >> #', each asString ].

	"Instance side methods"
	aClass selectors do: [ :each |
		self crTrace: aClass name, ' >> #', each asString ]
]
