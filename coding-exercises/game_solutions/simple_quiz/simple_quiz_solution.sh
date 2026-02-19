#!/bin/bash

score=0

read -p "What is the capital of France? " a1
if [[ "${a1,,}" == "paris" ]]; then
  echo "Correct!"
  ((score++))
else
  echo "Incorrect. The answer is Paris."
fi

read -p "What does CPU stand for? " a2
if [[ "${a2,,}" == *"central processing unit"* ]]; then
  echo "Correct!"
  ((score++))
else
  echo "Incorrect. The answer is Central Processing Unit."
fi

read -p "What language is known for indentation? " a3
if [[ "${a3,,}" == "python" ]]; then
  echo "Correct!"
  ((score++))
else
  echo "Incorrect. The answer is Python."
fi

echo ""
echo "Your final score: $score/3"
