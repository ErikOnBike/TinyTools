Extension { #name : #AdditionalMethodState }

{ #category : #'*TinyTools' }
AdditionalMethodState >> ttEncodeWith: anEncoder [

	self hasNonEmptyProperties
		ifTrue: [ self error: 'Methods with properties are currently not supported' ].

	anEncoder encodeAdditionalMethodState: self
]
