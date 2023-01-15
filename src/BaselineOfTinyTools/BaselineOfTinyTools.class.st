Class {
	#name : #BaselineOfTinyTools,
	#superclass : #BaselineOf,
	#category : #BaselineOfTinyTools
}

{ #category : #baselines }
BaselineOfTinyTools >> baseline: spec [

	<baseline>

	spec for: #common do: [

		"Packages"
		spec package: 'TinyTools'.

		"Groups"
		spec 
			group: 'default' with: #( 'TinyTools' ) ]
]
