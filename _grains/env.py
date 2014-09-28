#!/usr/bin/env python
# simple grain to import entire environment to grain 'env'
import os 
def env(): 
    return { 'env': os.environ.data } 