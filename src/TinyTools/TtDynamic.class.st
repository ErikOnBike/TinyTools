"
I am a placeholder class for the TtDynamic class in the 'default' tiny image.
You can use me to add single methods to test things regarding installing methods
into the tiny image.

"
Class {
	#name : #TtDynamic,
	#superclass : #Object,
	#category : #'TinyTools-Core'
}

{ #category : #tests }
TtDynamic class >> test1 [

	self crTrace: 'Running test1'
]

{ #category : #tests }
TtDynamic class >> test1and2 [

	self
		test1 ;
		test2
]

{ #category : #tests }
TtDynamic class >> test2 [

	self crTrace: 'Running test2'
]
