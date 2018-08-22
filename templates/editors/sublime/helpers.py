#!/usr/bin/env python

import os
import signal
import subprocess
import errno
import shutil
import urllib2
import glob

# A class containting static helper methods used to perform the install + config
class Helpers():

	# Check to see if an application is installed
	@staticmethod
	def is_installed(app_path):
		try:
			p = subprocess.Popen(app_path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
			os.kill(p.pid, signal.SIGTERM)
			return True
		except OSError as e:
			return False

	# create a directory if it doesn't already exist
	@staticmethod
	def make_dir(dir):
		subprocess.call(['mkdir', '-p', dir])

    # recursively copies all the files in a directory
	#  required because shutil.copytree (sucks) can't overwrite directories
	@staticmethod
	def copytree(src, dst, symlinks=False, ignore=None):
		for item in os.listdir(src):
			s = os.path.join(src, item)
			d = os.path.join(dst, item)
			if os.path.isdir(s):
				try:
					shutil.copytree(s, d, symlinks, ignore)
				except OSError as exception:
					if exception.errno != errno.EEXIST:
						raise
					else:
						shutil.copy2(s, d)

	# Ensure unique elements in python array
	@staticmethod
	def uniquify(seq, idfun=None):
	   if idfun is None:
	       def idfun(x): return x
	   seen = {}
	   result = []
	   for item in seq:
	       marker = idfun(item)
	       # in old Python versions:
	       # if seen.has_key(marker)
	       # but in new ones:
	       if marker in seen: continue
	       seen[marker] = 1
	       result.append(item)
	   return result

	# Enable path autocomplete relative to /
	@staticmethod
	def complete(text, state):
		return (glob.glob(text+'*')+[None])[state]

	@staticmethod
	def install_package_control(config_path):
		path = config_path + '/Installed Packages/Package Control.sublime-package'
		url = 'http://sublime.wbond.net/Package%20Control.sublime-package'
		response = urllib2.urlopen(url)
		CHUNK = 16 * 1024
		with open(path, 'wb') as f:
			while True:
				chunk = response.read(CHUNK)
				if not chunk: break
				f.write(chunk)

