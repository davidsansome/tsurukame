package utils

import (
	"net/url"
)

func Must(err error) {
	if err != nil {
		panic(err)
	}
}

func MustParseURL(str string) *url.URL {
	ret, err := url.Parse(str)
	Must(err)
	return ret
}
