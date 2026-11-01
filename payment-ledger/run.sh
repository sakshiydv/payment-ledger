#!/usr/bin/env bash
# Start the Payment Ledger app with the correct Java (17) and corporate truststore.
# Usage:  bash run.sh
# This sets Java 17 for THIS command only — your global Java (8/11) is untouched.

export JAVA_HOME="$HOME/.sdkman/candidates/java/17.0.17-amzn"
export MAVEN_OPTS="-Djavax.net.ssl.trustStore=$HOME/.sdkman/candidates/java/11.0.24-amzn/lib/security/cacerts -Djavax.net.ssl.trustStorePassword=changeit"

echo "Using Java: $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
exec mvn spring-boot:run
