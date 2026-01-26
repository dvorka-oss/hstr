# Copilot instructions

This document provides instructions to the copilot AI assistants and agents.

## General instructions

- Write beautiful code.
- Handle for errors, and exceptions and corner cases.
- Do good and don't be evil.

## Functional architecture instructions

- This repository is a monorepo of a sport training log web application.

## Technology stack instructions

- Frontend: Jinja templates, Tabler component and CSS framework, HTML, JavaScript.
- Backend: Python, Flask, WTForms, Bokeh.
- Persistence: JSON files on the local filesystem.

## Backend code instructions

- Application backend is written in Python.
- Always use up to Python 3.10 language constructions and avoid newer language features.
- Work with backend code stored in the mytral/ directory.
- Use type hints in Python - avoid Optional and Union from typing.
- Always start comments you generate with lowercase letter.
- Always use `numpy` docstring convention.
- Always use Google code style imports - import module, not symbols (except typing).
- Use WTForms for forms and their validation.
- Use Bokeh for chart generation.

## Security instructions

- NEVER log, print, or output sensitive data such as passwords, tokens, API keys, secrets, or any authentication credentials.
- NEVER log form data that may contain sensitive information (e.g., password fields, password_confirm fields).
- When debugging authentication or user input, log only non-sensitive metadata (e.g., "Password validation successful" instead of actual password values).

## Backend code quality instructions

- NEVER use hacks or workarounds to make tests pass - always write clean, production-quality code.
- NEVER add noqa comments to silence linters unless there's a legitimate architectural reason (not for test convenience).
- NEVER modify production code with ugly hacks just to make tests work - fix tests properly or remove them.
- Note that there is used `flake8` with `pyproject.toml` for the Python code quality.
- Note that there is used `black` with 88 columns for the Python formatting.
- Note that there is used `isort` for the Python imports sorting and `.isort.cfg` in the root directory.
- ALWAYS follow clean code principles - imports belong at the top of files, not at the bottom.

## Frontend instructions

- Application frontend is written in Jinja templates served by the Flask server.
- Jinja templates contain HTML and CSS code bases on the `Tabler` framework.
- Use `Tabler` components and CSS styles and always review existing pages to make new code consistent with the existing code.
- When you use `badge` CSS class, always use corresponding `text-*-fg` class for the text color definition.
- Work with frontend Jinja templates code stored in the mytral/templates directory.
- Use Jinja formatting with 4 spaces indentation in templates.

## Test instructions

- Write Python backend tests for all the code.
- Use `pytest` for testing.
- Mark the tests with `@pytest.mark.mytral`.
- Each test (function) is structured into 3 sections: # GIVEN, # WHEN, and # THEN. # GIVEN section prepares the data, # WHEN section performs the actual test, and # THEN section asserts, checks and prints the results.
- Use `DONE` instead of emoji character ✓ (do not use emoji/unicode characters, use the text inside)

## Build instructions

- The project is built with `make`.
- Use `uv` for the Python dependency management.
- Use `pyproject.toml` to manage dependencies, build and testing.

## Deployment instructions

- Keep in mind that the project is hosted by pythonanywhere.com
- Be aware that the project uses mytral.fitness domain.

