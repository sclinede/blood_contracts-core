# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.4.4] - [2019-08-30]

Features/Fixes:
- Changed the way we treat context in Sum and Tuple. Each validation of those aggregations now uses its own context.
  In other word, each validation path has its own context, which will not be corrupted in parallel validaions.
  If validation succeded we return the only valid context, otherwise if we failed on Tuple or Sum we return set of
  contexts, to inspect why did validation fail.

## [0.4.3] - yanked

## [0.4.2] - [2019-08-29]

Features:

- `BC::Tuple#argument` accepts an optional block to define the attribute class dynamically
- `BC::Tuple#match` can accept arguments as a Hash

## [0.4.1] - [2019-07-04]

Fixes:

Replaces the default context object in BC::Refined with simple Hash. No need to have default value for the context
key elements. It violates principlke of least surprise.

## [0.4.0] - [2019-06-25]

This is a first public release marked in change log with features extracted from production app.
Includes:
- Base class BloodContracts::Core::Refined to write your own validations
- Meta classes BloodContracts::Core::Pipe, BloodContracts::Core::Sum and BloodContracts::Core::Tuple for validations composition in ADT style
- BloodContracts::Core::Contract meta class as a syntactic sugar to define your own contracts with Refined validations under the hood
