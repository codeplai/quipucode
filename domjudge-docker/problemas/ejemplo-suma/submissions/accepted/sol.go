package main

import (
	"bufio"
	"fmt"
	"os"
)

var reader *bufio.Reader
var writer *bufio.Writer

func main() {
	reader = bufio.NewReader(os.Stdin)
	writer = bufio.NewWriter(os.Stdout)
	defer writer.Flush()

	var a, b int
	fmt.Fscan(reader, &a, &b)
	fmt.Fprintln(writer, a+b)
}
