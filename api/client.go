package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	"github.com/davidsansome/wk/utils"
)

const (
	urlBase = "https://www.wanikani.com/api/v2"
)

type Client struct {
	token  string
	client *http.Client
}

func New(token string) (*Client, error) {
	if len(token) != 36 {
		return nil, fmt.Errorf("Bad length API token: %s", token)
	}
	return &Client{
		token:  token,
		client: &http.Client{},
	}, nil
}

func (c *Client) get(u *url.URL) (*http.Response, error) {
	resp, err := c.client.Do(&http.Request{
		URL: u,
		Header: map[string][]string{
			"Authorization": []string{"Token token=" + c.token},
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

type subjectsCursor struct {
	c    *Client
	next *url.URL
	ret  []*SubjectObject
}

func (c *Client) Subjects() *subjectsCursor {
	return &subjectsCursor{
		c:    c,
		next: utils.MustParseURL(urlBase + "/subjects"),
	}
}

func (c *subjectsCursor) Next() (*SubjectObject, error) {
	if len(c.ret) == 0 {
		if c.next == nil {
			return nil, nil
		}

		resp, err := c.c.get(c.next)
		if err != nil {
			return nil, err
		}

		var coll subjectCollection
		d := json.NewDecoder(resp.Body)
		if err := d.Decode(&coll); err != nil {
			return nil, err
		}

		c.next, err = url.Parse(coll.Pages.NextURL)
		if err != nil {
			return nil, err
		}
		c.ret = coll.Data
	}

	ret := c.ret[0]
	c.ret = c.ret[1:len(c.ret)]
	return ret, nil
}
