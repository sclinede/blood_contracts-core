# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.4.0] - [2019-06-25]

This is a first public release marked in change log with features extracted from production app.
Includes:
- Base class BloodContracs::Core::Refined to write your own validations
- Meta classes BloodContracs::Core::Pipe, BloodContracs::Core::Sum and BloodContracs::Core::Tuple for validations composition in ADT style
- BloodContracs::Core::Contract meta class as a syntactic sugar to define your own contracts with Refined validations under the hood
