Extension { #name : #Association }

{ #category : #'*TinyTools' }
Association >> ttEncodeWith: anEncoder [

	(#(#Association #ClassVariable #GlobalVariable #UndeclaredVariable #LiteralVariable) includes: self class name)
		ifFalse: [ self error: 'Unsupported Association type' ].

	anEncoder encodeAssociation: self
]
