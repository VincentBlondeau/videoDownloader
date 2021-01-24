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
VideoDownloader class >> on: inputFile to: outputFile [

	^ self new
		  inputFile: inputFile;
		  outputFile: outputFile;
		  run
]

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

{ #category : #'as yet unclassified' }
VideoDownloader >> findMetaDataForPlayList: aString [ 
	self shouldBeImplemented.
]

{ #category : #'as yet unclassified' }
VideoDownloader >> findMetaDataForPlayList: playListEntry in: entries [

	| urlsUuid metaData string data |
	urlsUuid := (playListEntry asZnUrl segments last substrings: '.')
		            first.
	metaData := (entries select: [ :e | 
		             ((e at: 'response') at: 'content')
			             at: 'text'
			             ifPresent: [ :f | f includesSubstring: urlsUuid  ]
			             ifAbsent: [ false ] ]) reject: [ :g | 
		            ((g at: 'request') at: 'url') endsWith: '.m3u8' ].

	string := ((metaData first at: 'response') at: 'content') at: 'text'.
	data := (NeoJSONReader fromString:
		         '{' , ((string copyAfter: ${) copyUpToLast: $}) , '}') at:
		        'media'.
	^Dictionary new
		at: #name put: (data at: 'name');
		at: #transcription
		put:
			(((data at: 'captions') detect: [ :e | (e at: 'language') = 'eng' ]) 
				 at: 'text');
		yourself
]

{ #category : #'as yet unclassified' }
VideoDownloader >> getPlayListsEntriesFrom: entries [

	| m3u8 m3u8Grouped urls |
	m3u8 := entries select: [ :e | 
		        ((e at: 'request') at: 'url') endsWith: '.m3u8' ].
	m3u8Grouped := m3u8 groupedBy: [ :e | (e at: 'request') at: 'url' ].
	^ (m3u8Grouped collect: [ :e | (e anyOne at: 'request') at: 'url' ])
		  values
]

{ #category : #'as yet unclassified' }
VideoDownloader >> inputFile: aFileReference [

	inputFile := aFileReference
]

{ #category : #'as yet unclassified' }
VideoDownloader >> outputFile: aFileReference [

	outputFile := aFileReference
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
