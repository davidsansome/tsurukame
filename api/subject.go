package api

type pageSpec struct {
	PerPage int    `json:"per_page"`
	NextURL string `json:"next_url"`
}

type subjectCollection struct {
	Pages pageSpec         `json:"pages"`
	Data  []*SubjectObject `json:"data"`
}

type SubjectObject struct {
	ID     int    `'json:"id"`
	Object string `json:"object"`
	Data   struct {
		Level           int    `json:"level"`
		Slug            string `json:"slug"`
		DocumentURL     string `json:"document_url"`
		Character       string `json:"character"`
		CharacterImages []struct {
			ContentType string `json:"content_type"`
			URL         string `json:"url"`
		} `json:"character_images"`
		Meanings []struct {
			Meaning string `json:"meaning"`
			Primary bool   `json:"primary"`
		}
	} `json:"data"`
}
