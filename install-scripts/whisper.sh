#!/bin/bash

#################################
# OPENAI WHISPER INSTALL SCRIPT #
#################################

# update
sudo apt update 

# install dependencies
sudo apt install ffmpeg python3-dev python3-pip git

# install whisper
pip install git+https://github.com/openai/whisper.git

# run whisper
whisper "example.mp3" --model medium.en > transcript.txt

# display transcript
vim transcript.txt