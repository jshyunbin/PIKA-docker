# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PIKA-docker is a Dockerized distribution of the AgileX PIKA robot's ROS software stack, intended for easy deployment and usage. The AgileX PIKA is a wheeled robot platform; its hardware interfaces and software architecture are documented in `agilex-pika-user-manual.pdf`.

## Current State

This repository is in early setup. No Docker or ROS configuration files exist yet. When adding them, follow the conventions typical for ROS-in-Docker setups (e.g., a `Dockerfile` at the root, a `docker-compose.yml`, and ROS workspace source under `src/`).
