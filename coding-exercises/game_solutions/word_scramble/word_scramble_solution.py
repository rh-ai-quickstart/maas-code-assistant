import random

word = "python"
scrambled = ''.join(random.sample(word, len(word)))
print(f"Unscramble this word: {scrambled}")

while True:
    guess = input("Your guess (or type 'quit' to exit): ").strip().lower()
    if guess == "quit":
        print("The correct word was:", word)
        break
    elif guess == word:
        print("🎉 You got it!")
        break
    else:
        print("Not quite, try again!")
