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

package jsonapi

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"

	"github.com/davidsansome/tsurukame/utils"
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
	log.Printf("Fetching %s", u)
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
	defer resp.Body.Close()
	return d.Decode(ret)
}

func (c *Client) GetRadical(id int) (ret *Radical, err error) {
	err = c.getSubject(id, "radical", &ret)
	return
}
