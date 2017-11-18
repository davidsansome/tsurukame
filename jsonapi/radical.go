package jsonapi

type Radical struct {
	Stroke      int    `json:"stroke"`
	Mnemonic    string `json:"mnemonic"`
	MeaningNote string `json:"meaning_note"`
}
