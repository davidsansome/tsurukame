// Copyright 2018 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"time"

	"github.com/jpillora/backoff"

	"github.com/davidsansome/tsurukame/utils"
)

const (
	urlBase = "https://api.wanikani.com/v2"

	backoffFactor = 2
	backoffMin    = time.Second
	backoffMax    = 10 * time.Second
	maxTries      = 10
)

type Client struct {
	token  string
	client *http.Client
	ticker *time.Ticker
	bo     *backoff.Backoff
}

func New(token string, requestInterval time.Duration) (*Client, error) {
	if len(token) != 36 {
		return nil, fmt.Errorf("Bad length API token: %s", token)
	}
	return &Client{
		token:  token,
		client: &http.Client{},
		ticker: time.NewTicker(requestInterval),
		bo: &backoff.Backoff{
			Factor: backoffFactor,
			Jitter: true,
			Min:    backoffMin,
			Max:    backoffMax,
		},
	}, nil
}

func (c *Client) get(u *url.URL) (*http.Response, error) {
	<-c.ticker.C

	log.Printf("Fetching %s", u)
	for i := 0; i < maxTries; i++ {
		resp, err := c.client.Do(&http.Request{
			URL: u,
			Header: map[string][]string{
				"Authorization": []string{"Token token=" + c.token},
			},
		})
		if err != nil {
			return nil, err
		}

		switch resp.StatusCode {
		case http.StatusTooManyRequests:
			d := c.bo.ForAttempt(float64(i))
			log.Printf("Request failed: %s, retrying after %s", resp.Status, d)
			time.Sleep(d)

		case http.StatusOK:
			return resp, nil

		default:
			return nil, fmt.Errorf("Request for %s failed: HTTP %s", u, resp.Status)
		}
	}
	return nil, fmt.Errorf("Request for %s failed too many times", u)
}

type subjectsCursor struct {
	c    *Client
	next *url.URL
	ret  []*SubjectObject
}

func (c *Client) Subjects(typ string) *subjectsCursor {
	u := utils.MustParseURL(urlBase + "/subjects")
	if typ != "" {
		q := url.Values{}
		q.Set("type", typ)
		u.RawQuery = q.Encode()
	}
	return &subjectsCursor{
		c:    c,
		next: u,
	}
}

func (c *Client) Close() {
	c.ticker.Stop()
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
		defer resp.Body.Close()

		var coll subjectCollection
		d := json.NewDecoder(resp.Body)
		if err := d.Decode(&coll); err != nil {
			return nil, err
		}

		if coll.Pages.NextURL == "" {
			c.next = nil
		} else {
			c.next, err = url.Parse(coll.Pages.NextURL)
			if err != nil {
				return nil, err
			}
		}
		c.ret = coll.Data
	}

	ret := c.ret[0]
	c.ret = c.ret[1:len(c.ret)]
	return ret, nil
}
