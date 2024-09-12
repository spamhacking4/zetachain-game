# Tic-Tac-Toe Game

def print_board(board):
    print(" " + " | ".join(board[0]))
    print("---+---+---")
    print(" " + " | ".join(board[1]))
    print("---+---+---")
    print(" " + " | ".join(board[2]))

def check_winner(board, player):
    # Check rows, columns, and diagonals
    for row in board:
        if all(cell == player for cell in row):
            return True
    for col in range(3):
        if all(board[row][col] == player for row in range(3)):
            return True
    if all(board[i][i] == player for i in range(3)):
        return True
    if all(board[i][2-i] == player for i in range(3)):
        return True
    return False

def is_full(board):
    return all(cell != " " for row in board for cell in row)

def get_move():
    while True:
        try:
            move = int(input("Enter your move (1-9): ")) - 1
            if move < 0 or move > 8:
                print("Move must be between 1 and 9.")
            return move
        except ValueError:
            print("Invalid input. Please enter a number between 1 and 9.")

def play_game():
    board = [[" " for _ in range(3)] for _ in range(3)]
    players = ["X", "O"]
    current_player = 0

    print("Tic-Tac-Toe")
    print("Player1 joins with Rs 100")
    print("Player2 joins with Rs 100")
    print("Player 1 (X) starts the game.")
    print_board(board)

    while True:
        print(f"Player {current_player + 1}'s turn.")
        move = get_move()
        row, col = divmod(move, 3)

        if board[row][col] != " ":
            print("Cell already occupied. Try again.")
            continue

        board[row][col] = players[current_player]
        print_board(board)

        if check_winner(board, players[current_player]):
            # print(f"Player {current_player + 1} wins!")
            print(f"Player {current_player + 1} wins Rs 200")
            break

        if is_full(board):
            print("It's a tie!")
            break

        current_player = 1 - current_player  # Switch players

if __name__ == "__main__":
    play_game()
