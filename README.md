# What is Capima?

Capima is a modern/minimal web server CLI tool designed to help you manage your PHP web application and websites.

> Installing, configuring and optimizing your web server has never been so easy.

# Getting Started

## Requirements

Before you can use Capima, please make sure your server fulfils these requirements.

Software requirement

* Ubuntu 16.04/18.04 x86_64 LTS (Fresh installation)
* If the server is virtual (VPS), OpenVZ may not be supported (Kernel 2.6)

Hardware requirement

* More than 1GB HDD
* At least 1 core processor
* 512MB minimum RAM

## Installation

via curl
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/nntoan/capima/master/files/installers/install.sh)"
```

via wget
```bash
sudo bash -c "$(wget https://raw.githubusercontent.com/nntoan/capima/master/files/installers/install.sh -O -)"
```

## Usage

After installed, you are able to manage your webservers by the following command.

```bash
$ sudo capima

CAPIMA v0.0.0

Usage:
 capima [commands] [options]

Options:
 --version(-v)    Display current version.
 --help(-h)       Display this help message.
 --quiet(-q)      Do not output any message.
 --ansi           Force ANSI output.
 --no-ansi        Disable ANSI output.

Available commands:
 web              Webapps management panel (add/update/delete).
 use              Switch between version of PHP-CLI.
 restart          Restart Capima services.
 info             Show webapps information (under development).
 logs             Tail the last 200 lines of logfile (apache,fpm,nginx).
 self-update      Check latest version and performing self-update.
```

## List of commands

Quick guide of commands available in Capima for configuration and adjustment of this application.

### WEB

Manage your websites, create, delete, disable your sites, enable SSL for any of your sites.

```
sudo capima web add
```

You will enter the interactive mode like the following screenshots