score = 0

answer1 = input("What is the capital of France? ").strip().lower()
if answer1 == "paris":
    print("Correct!")
    score += 1
else:
    print("Incorrect. The answer is Paris.")

answer2 = input("What does CPU stand for? ").strip().lower()
if "central processing unit" in answer2:
    print("Correct!")
    score += 1
else:
    print("Incorrect. The answer is Central Processing Unit.")

answer3 = input("What language is known for indentation? ").strip().lower()
if answer3 == "python":
    print("Correct!")
    score += 1
else:
    print("Incorrect. The answer is Python.")

print(f"\nYour final score: {score}/3")
