#!/bin/bash

# A tmux script to create a multi-window session for development.
# Window 1: "claude" - A 4-pane dashboard.
# Window 2: "dev/git" - A 2-pane vertical split for coding and version control.

SESSION_NAME="devA"

# Check if the session already exists. If not, create and configure it.
# The '2>/dev/null' part silences the "can't find session" error.
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # --- SESSION SETUP ---
    # Create a new detached session and name the first window "claude".
    tmux new-session -d -s $SESSION_NAME -n "claude"

    # --- WINDOW 1: "claude" (4 Panes) ---
    # Pane 1 is created by default.
    # Split it horizontally to create top and bottom sections.
    tmux split-window -v -t $SESSION_NAME:claude.1

    # Select the top pane (pane 1) and split it vertically.
    tmux split-window -h -t $SESSION_NAME:claude.1

    # Select the bottom pane (now pane 3) and split it vertically.
    tmux split-window -h -t $SESSION_NAME:claude.3

    # Optional: Send commands to each pane for a "ready-to-go" feel.
    tmux send-keys -t $SESSION_NAME:claude.1 "cmatrix -b" C-m
    tmux send-keys -t $SESSION_NAME:claude.2 "cmatrix -b" C-m
    tmux send-keys -t $SESSION_NAME:claude.3 "cmatrix -b" C-m
    tmux send-keys -t $SESSION_NAME:claude.4 "cmatrix -b" C-m


    # --- WINDOW 2: "dev/git" (2 Panes) ---
    # Create a new window named "dev/git".
    tmux new-window -n "dev/git" -t $SESSION_NAME

    # Split the new window vertically into two equal panes.
    tmux split-window -h -t $SESSION_NAME:dev/git.1

    # Optional: Send commands to the dev/git panes.
    tmux send-keys -t $SESSION_NAME:dev/git.1 "cmatrix -b" C-m # Open editor in left pane
    tmux send-keys -t $SESSION_NAME:dev/git.2 "cmatrix -b" C-m # Open lazygit in right pane


    # --- FINAL SETUP ---
    # Select the "claude" window to be the default on attach.
    tmux select-window -t $SESSION_NAME:claude
fi

# Attach to the session, whether it was new or already existed.
tmux attach-session -t $SESSION_NAME