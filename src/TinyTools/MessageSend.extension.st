Extension { #name : #MessageSend }

{ #category : #'*TinyTools' }
MessageSend >> ttEncodeWith: anEncoder [

	anEncoder encodeMessageSend: self
]
