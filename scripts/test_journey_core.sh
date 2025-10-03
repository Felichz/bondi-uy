#!/bin/bash

# Script para ejecutar tests del Journey Core y mostrar reporte
# Este script proporciona feedback instantáneo para desarrollo con LLM

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 JOURNEY CORE - Test Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓${NC} $2"
  else
    echo -e "${RED}✗${NC} $2"
  fi
}

# Test individual files
TEST_FILES=(
  "test/journey/core/trip_state_machine_test.dart"
  "test/journey/core/step_detector_test.dart"
  "test/journey/core/trip_integration_test.dart"
  "test/journey/core/trip_multileg_test.dart"
)

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}📋 Ejecutando tests unitarios...${NC}"
echo ""

for test_file in "${TEST_FILES[@]}"; do
  test_name=$(basename "$test_file" .dart)
  echo -e "${YELLOW}▶${NC} $test_name"

  # Ejecutar test y capturar resultado
  if flutter test "$test_file" --no-pub > /tmp/test_output.txt 2>&1; then
    # Contar tests
    tests_count=$(grep -o "+[0-9]*" /tmp/test_output.txt | tail -1 | tr -d '+')
    print_status 0 "$test_name ($tests_count tests)"
    PASSED_TESTS=$((PASSED_TESTS + tests_count))
    TOTAL_TESTS=$((TOTAL_TESTS + tests_count))
  else
    # Extraer información de fallo
    tests_passed=$(grep -o "+[0-9]*" /tmp/test_output.txt | tail -1 | tr -d '+')
    tests_failed=$(grep -o "\-[0-9]*" /tmp/test_output.txt | tail -1 | tr -d '-')

    print_status 1 "$test_name ($tests_passed passed, $tests_failed failed)"

    PASSED_TESTS=$((PASSED_TESTS + tests_passed))
    FAILED_TESTS=$((FAILED_TESTS + tests_failed))
    TOTAL_TESTS=$((TOTAL_TESTS + tests_passed + tests_failed))

    # Mostrar errores
    echo ""
    echo -e "${RED}Error details:${NC}"
    grep -A 5 "Expected:" /tmp/test_output.txt || echo "See /tmp/test_output.txt for details"
    echo ""
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMEN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total tests:   $TOTAL_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
  echo -e "${GREEN}✓ Passed:      $PASSED_TESTS${NC}"
  echo -e "${GREEN}✗ Failed:      $FAILED_TESTS${NC}"
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ TODOS LOS TESTS PASARON${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  echo -e "${GREEN}✓ Passed:      $PASSED_TESTS${NC}"
  echo -e "${RED}✗ Failed:      $FAILED_TESTS${NC}"
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ ALGUNOS TESTS FALLARON${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Ver detalles en: /tmp/test_output.txt"
  exit 1
fi
