Extension { #name : #Integer }

{ #category : #'*TinyTools' }
Integer >> ttEncodeWith: anEncoder [

	anEncoder encodeInteger: self
]
