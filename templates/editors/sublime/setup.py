#!/usr/bin/env python

import platform
import sys
import os
import subprocess
import readline
import json
import codecs
import copy

from helpers import Helpers

platform = platform.system()
app_path = ''
config_path = ''

# the application main entry point
def main():
	print('Configuring SublimeText editor .....')
	print('Checking your operating system .....')

	# OSX Setup:
	# - check and install via `brew cask`
	# - copy configuration to '/Library/Application Support/Sublime Text 3'

	if platform == 'Darwin':
		print('OSX operating system detected !')

		app_path = '/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl'
		config_path = os.path.expanduser('~') + '/Library/Application Support/Sublime Text 3'

		if not Helpers.is_installed(app_path):
			print('We detected that SublimeText is not installed. We will install it now ...')
			install_osx(app_path)
		config(config_path)
		configure_projects(config_path)
		sys.exit(0)

	# Linux Setup:
	# - check and install via `apt-get`
	# - copy configuration to '~/.config/sublime-text-3'

	if platform == 'Linux':
		print('Linux operating system detected ...')

		app_path = 'sublime'
		config_path = os.path.expanduser('~') + '/.config/sublime-text-3'

		if not Helpers.is_installed(app_path):
			print('Sublime not installed...')
			install_linux(app_path)
		config(config_path)
		configure_projects(config_path)
		sys.exit(0)

# Automatically onfigure a list of projects into SublimeText
def configure_projects(config_path):

	def create_sublime_project(project_path, config_path):

		# Define the path of the sublime project
		sublime_session_path = config_path + "/Local/Session.sublime_session"
		project_name         = project_path.split('/')[-1]

		# Create the .sublime-project data
		sublime_project = {"folders": []}
		sublime_project["folders"].append({"path": project_path })

		sublime_workspace_path = project_path + "/" + project_name + ".sublime-workspace"
		sublime_project_path   = project_path + "/" + project_name + ".sublime-project"

		# Create the .sublime-workspace which is just a default empty JSON
		print("--> creating sublime project in: " + project_path)

		with open(sublime_project_path, 'w') as project:
			project.write(json.dumps(sublime_project, ensure_ascii=False))
		with open(sublime_workspace_path, 'w') as workspace:
			workspace.write(json.dumps({}, ensure_ascii=False))

		# Now we need to make sure that we add this to the Session.sublime_session
		if os.path.exists(sublime_session_path):
			# We need just to append the new project names now
			with codecs.open(sublime_session_path, 'rU','utf-8') as session_file:
				sublime_session = copy.deepcopy(json.load(session_file))
				sublime_session["workspaces"]["recent_workspaces"].append(sublime_workspace_path)
				sublime_session["workspaces"]["recent_workspaces"] = Helpers.uniquify(sublime_session["workspaces"]["recent_workspaces"])
				with codecs.open(sublime_session_path, 'w', encoding="utf-8") as session:
					session.write(json.dumps(sublime_session, ensure_ascii=False))
		else:
			# We need to create the file and fill it up at least for the first time
			sublime_session = {"workspaces" : { "recent_workspaces": [] }}
			sublime_session["workspaces"]["recent_workspaces"].append(sublime_workspace_path)
			sublime_session["workspaces"]["recent_workspaces"] = Helpers.uniquify(sublime_session["workspaces"]["recent_workspaces"])
			with open(sublime_session_path, 'w') as session:
				session.write(json.dumps(sublime_session, ensure_ascii=False))

	configure = raw_input("Would you like to setup automatically a list of projects into SublimeText ? [y/n] : ")

	if configure == "y":
		choice = raw_input("Would you like to setup multiple projects or single project ? [m(multiple)/s(single)] : ")
		if choice == "m":
			while True:
					readline.set_completer_delims(' \t\n;')
					readline.parse_and_bind("tab: complete")
					readline.set_completer(Helpers.complete)
					parent_folder = raw_input("Please enter destination of the parent folder. Note that all subfolders will be added as project (type 'exit' anytime to quit): ")
					if parent_folder.strip() == 'exit':
							break
					if os.path.exists(parent_folder) and os.path.isdir(parent_folder):
						# List all folders immediately under this folder:
						dirs = (next( os.walk(parent_folder) )[1])
						for dir in dirs:
							if dir.startswith("."):
								continue
							create_sublime_project(parent_folder + "/" + dir, config_path)
					else:
						print("this does not seem to be a valid path :(")
		elif choice == "s":
			while True:
				readline.set_completer_delims(' \t\n;')
				readline.parse_and_bind("tab: complete")
				readline.set_completer(Helpers.complete)
				destination_folder = raw_input("Please enter destination of the folder. (type 'exit' anytime to quit): ")
				if destination_folder.strip() == 'exit':
					break
				if os.path.exists(destination_folder) and os.path.isdir(destination_folder):
					create_sublime_project(destination_folder, config_path)
				else:
					print("this does not seem to be a valid path :(")

# OSX installation instructions
def install_osx(app_path):

	install_path = '/opt/homebrew-cask/Caskroom/sublime-text3/build 3083/Sublime Text.app/Contents/SharedSupport/bin/subl'

	try:

		if not Helpers.is_installed(['brew', 'help', '&>/dev/null']):
			raise NotInstalledError('Error: Homebrew required to install Sublime Text.')
		print('Updating sources...')

		subprocess.call(['brew', 'update'])
		print('Installing Sublime Text...')

		os.environ['HOMEBREW_CASK_OPTS'] = '--appdir=/Applications'
		subprocess.call(['brew', 'tap', 'caskroom/versions'])
		subprocess.call(['brew', 'cask', 'install', 'sublime-text'])

		# symlink to 'sublime'
		subprocess.Popen(['ln', '-s', install_path, '/usr/local/bin/sublime'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

		print('Installation complete...')
	except Exception as e:
		print(e)
		sys.exit(1)


# Linux installation instructions
def install_linux(app_path):
	try:
		subprocess.call(['sudo', 'id', '-nu'], stdout=subprocess.PIPE)
		print('Updating sources...')
		subprocess.call(['sudo', 'apt-get', 'update'])
		print('Installing Sublime Text...')
		subprocess.call(['sudo', 'apt-get', 'install', 'sublime-text'])
		print('Installation complete...')
	except OSError as e:
		print(e)
		sys.exit(1)


# configuration instructions
def config(config_path):

	configure = raw_input("Running now SublimeText configuration based on the templates provided\nThie will overwrite any existing configs if found, continue ? [y/n] : ")

	if configure == "y":
		packages = config_path + '/Installed Packages'
		settings = config_path + '/Packages/User'

		# create the settings directories
		Helpers.make_dir(config_path)
		Helpers.make_dir(packages)
		Helpers.make_dir(settings)

		# install 'Package Control'
		Helpers.install_package_control(config_path)

		# copy the themes
		Helpers.copytree(os.path.dirname(__file__) + '/themes', packages)

		# copy the user preferences
		Helpers.copytree(os.path.dirname(__file__) + '/user-settings', settings)

		print('SublimeText configuration completed successfully ...')
	else:
		print('SublimeText configuration not changed .. all is complete !')

# Custom exception, indicates that a dependency is not installed
class NotInstalledError(Exception):
	pass


if __name__ == '__main__':
	try:
		main()
	except KeyboardInterrupt:
		print("\nCaught KeyboardInterrupt :(, terminating now ..")
		sys.exit(1)
