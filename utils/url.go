package utils

import (
	"net/url"
)

func MustParseURL(str string) *url.URL {
	ret, err := url.Parse(str)
	if err != nil {
		panic(err)
	}
	return ret
}
