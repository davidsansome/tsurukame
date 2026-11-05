`generate.swift` builds the app's
`ios/WaniKaniAPI/Sources/WaniKaniAPI/Resources/word-frequency.json`, which says
how common each WaniKani vocabulary subject is. It takes a copy of the app's
`local-cache.db` to get the list of vocabulary subjects and their readings:

    swift word_frequency/generate.swift path/to/local-cache.db

Run it again when WaniKani adds new vocabulary. On first run it downloads these
into `word_frequency/cache/`:

- [JMdict](https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project)
  from the Electronic Dictionary Research and Development Group. A word is
  "common" if JMdict gives it one of the `news1`, `ichi1`, `spec1`, `spec2` or
  `gai1` priority tags - the same thing Jisho and other dictionaries mark as
  common.
- Three frequency lists, which give each word's rank:
  - The [jiten.moe](https://jiten.moe/frequency-dictionaries) global list,
    from anime, drama, films, novels, visual novels and other media.
  - The jiten.moe non-fiction list, from 112 non-fiction books.
  - [wordfreq](https://github.com/rspeer/wordfreq), from Wikipedia, film
    subtitles, web text, Twitter and Reddit.

  A word's rank is the geometric mean of its ranks in the lists that have it.
  The jiten.moe global list on its own ranks formal words like 政府 and 憲法
  far too low, and wordfreq on its own is missing compounds like 一人 and
  外国人, but together they're balanced and cover almost all WaniKani
  vocabulary.

All of these are licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), and so is the
generated `word-frequency.json`. They're credited in the app's Settings >
Credits screen.

[BCCWJ](https://clrd.ninjal.ac.jp/bccwj/en/freq-list.html) would be the ideal
balanced list, but its terms don't allow it to be redistributed.
