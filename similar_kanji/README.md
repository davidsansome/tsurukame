The json files in this directory are from
https://github.com/mwil/wanikani-userscripts/tree/master/wanikani-similar-kanji/db

`generate.swift` combines them into the app's
`ios/WaniKaniAPI/Sources/WaniKaniAPI/Resources/visually-similar-kanji.json`.
Run it after changing any of the json files here:

    swift similar_kanji/generate.swift
