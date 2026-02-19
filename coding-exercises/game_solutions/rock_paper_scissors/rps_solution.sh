#!/bin/bash

options=("rock" "paper" "scissors")
computer_choice=${options[$RANDOM % 3]}

read -p "Choose rock, paper, or scissors: " user_choice
echo "Computer chose: $computer_choice"

if [[ "$user_choice" == "$computer_choice" ]]; then
    echo "It's a tie!"
elif [[ ("$user_choice" == "rock" && "$computer_choice" == "scissors") ||
        ("$user_choice" == "paper" && "$computer_choice" == "rock") ||
        ("$user_choice" == "scissors" && "$computer_choice" == "paper") ]]; then
    echo "You win! 🎉"
else
    echo "You lose! 😢"
fi