package jsonapi

type Kanji struct {
	Stroke          int    `json:"stroke"`
	MeaningMnemonic string `json:"meaning_mnemonic"`
	MeaningHint     string `json:"meaning_hint"`
	ReadingMnemonic string `json:"reading_mnemonic"`
	ReadingHint     string `json:"reading_hint"`
}
