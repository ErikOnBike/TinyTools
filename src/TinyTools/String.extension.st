Extension { #name : #String }

{ #category : #'*TinyTools' }
String >> ttEncodeWith: anEncoder [

	anEncoder encodeString: self
]
