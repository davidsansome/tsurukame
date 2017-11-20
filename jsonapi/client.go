package jsonapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	"github.com/davidsansome/wk/utils"
)

const (
	urlBase = "https://www.wanikani.com/json"
)

type Client struct {
	cookie string
	client *http.Client
}

func New(cookie string) (*Client, error) {
	if len(cookie) != 32 {
		return nil, fmt.Errorf("Bad length cookie: %s", cookie)
	}
	return &Client{
		cookie: cookie,
		client: &http.Client{},
	}, nil
}

func (c *Client) get(u *url.URL) (*http.Response, error) {
	resp, err := c.client.Do(&http.Request{
		URL: u,
		Header: map[string][]string{
			"Cookie": []string{"_wanikani_session=" + c.cookie},
		},
	})
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Request for %s failed: HTTP %s", u, resp.Status)
	}
	return resp, nil
}

func (c *Client) getSubject(id int, typ string, ret interface{}) error {
	resp, err := c.get(utils.MustParseURL(fmt.Sprintf("%s/%s/%d", urlBase, typ, id)))
	if err != nil {
		return err
	}

	d := json.NewDecoder(resp.Body)
	return d.Decode(ret)
}

func (c *Client) GetRadical(id int) (ret *Radical, err error) {
	err = c.getSubject(id, "radical", &ret)
	return
}

func (c *Client) GetKanji(id int) (ret *Kanji, err error) {
	err = c.getSubject(id, "kanji", &ret)
	return
}

func (c *Client) GetVocabulary(id int) (ret *Vocabulary, err error) {
	err = c.getSubject(id, "vocabulary", &ret)
	return
}
