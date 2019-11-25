# What is Capima?

Capima is a modern/minimal web server CLI tool designed to help you manage your PHP web application and websites.

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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/nntoan/capima/master/files/installers/install.sh)"
```

via wget
```bash
sh -c "$(wget https://raw.githubusercontent.com/nntoan/capima/master/files/installers/install.sh -O -)"
```

## Usage

```bash
$ capima

CAPIMA v1.0.2

Usage:
 capima [commands] [options]

Options:
 --version(-v)    Display current version.
 --help(-h)       Display this help message.
 --quiet(-q)      Do not output any message.
 --ansi           Force ANSI output.
 --no-ansi        Disable ANSI output.

Available commands:
 new              Create new webapp in Capima.
 use              Switch between version of PHP-CLI.
 restart          Restart all Capima services.
 logs             Tail the last 200 lines of logfile (apache,fpm,nginx).
 self-update      Check latest version and performing self-update.
```