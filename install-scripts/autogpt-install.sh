#!/bin/bash

# ----------------------- #
# AutoGPT Install & Setup #
# ----------------------- #

## fist update your system

sudo apt update
sudo apt upgrade -y

## next create a new conda env

conda create --name <example> python=3.10 # change to desired env name
conda activate <example>

## clone the autogpt repo

git clone https://github.com/Significant-Gravitas/Auto-GPT.git
cd Auto-GPT.git

## install requirements 

pip install -r requirements.txt
#pip3 install -r requirements.txt

## create your .env file (used to store your API keys)

cp .env.template .env
vim .env # add your api keys / env varriables

## run program 

python -m <example> 
#python3 -m <example>
