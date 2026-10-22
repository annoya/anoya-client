//go:build !darwin || !cgo

package engine

func physFootprint() int64 { return -1 }
