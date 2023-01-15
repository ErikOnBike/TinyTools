Extension { #name : #LiteralVariable }

{ #category : #'*TinyTools' }
LiteralVariable >> ttEncodeWith: anEncoder [

	"Encode the receiver based on fact that it implements similar protocol as Associaton (ie #key and #value)"

	anEncoder encodeAssociation: self
]
