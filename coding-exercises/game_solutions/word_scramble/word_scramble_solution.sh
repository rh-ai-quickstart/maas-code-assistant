#!/bin/bash

original="python"
letters=($(echo $original | grep -o .))
scrambled=$(printf "%s\n" "${letters[@]}" | shuf | tr -d '\n')

echo "Unscramble this word: $scrambled"

while true; do
  read -p "Your guess (or type 'quit'): " guess
  if [[ "$guess" == "quit" ]]; then
    echo "The correct word was: $original"
    break
  elif [[ "$guess" == "$original" ]]; then
    echo "🎉 You got it!"
    break
  else
    echo "Not quite, try again!"
  fi
done
