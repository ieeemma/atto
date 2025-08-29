#!/bin/sh

gleam test
(cd example/calculator && gleam test)
(cd example/json_parser && gleam test)
