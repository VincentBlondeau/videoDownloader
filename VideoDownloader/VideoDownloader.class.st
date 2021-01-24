Class {
	#name : #VideoDownloader,
	#superclass : #Object,
	#instVars : [
		'inputFile',
		'outputFile',
		'metaData'
	],
	#category : #VideoDownloader
}

{ #category : #'as yet unclassified' }
VideoDownloader class >> withInteraction [

	| from to |
	from := UIManager default chooseExistingFileReference: 'Get the HAR file to load'  extensions: #('har') path: '' .
	from ifNil: [ ^self ].
	to := UIManager default chooseDirectory: 'Choose the export directory'.
	to ifNil: [ ^self ].
	self on: from to: to
]

{ #category : #'as yet unclassified' }
VideoDownloader >> download [

	outputFile ensureCreateDirectory.
	metaData do: [ :meta | self downloadOne: meta ]
]

{ #category : #'as yet unclassified' }
VideoDownloader >> downloadOne: anAssociation [

	| name |
	name := anAssociation value at: #name.
	(outputFile / (name , '.txt')) ensureCreateFile writeStreamDo: [ :ws | 
		ws nextPutAll: (anAssociation value at: #transcription) ].
	LibC runCommand:
		'FFMPEG\youtube-dl.exe --retries "infinite" -o "'
		, (outputFile / name) pathString , '.%(ext)s" ' , anAssociation key
]

{ #category : #running }
VideoDownloader >> run [

	| json entries playListEntries |
	json := inputFile readStreamDo: [ :s | (NeoJSONReader on: s) next ].
	entries := (json at: 'log') at: 'entries'.
	playListEntries := self getPlayListsEntriesFrom: entries.
	metaData := playListEntries collect: [ :e | 
		            e -> (self findMetaDataForPlayList: e in: entries) ].
	metaData := (TickDialogWindow itemsList: metaData itemsHeaderName: 'Choose Videos To Download' wrapBlockOrSelector: [ :e | e value at: #name ] title: 'Videos') choose.
	self download
]
