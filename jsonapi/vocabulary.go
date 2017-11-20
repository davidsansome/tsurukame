package jsonapi

type Vocabulary struct {
	Stroke             int        `json:"stroke"`
	MeaningExplanation string     `json:"meaning_explanation"`
	ReadingExplanation string     `json:"reading_explanation"`
	Sentences          [][]string `json:"sentences"`
	Audio              string     `json:"audio"`
}
