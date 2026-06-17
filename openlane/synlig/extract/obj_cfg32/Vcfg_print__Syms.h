// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VCFG_PRINT__SYMS_H_
#define VERILATED_VCFG_PRINT__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vcfg_print.h"

// INCLUDE MODULE CLASSES
#include "Vcfg_print___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vcfg_print__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vcfg_print* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vcfg_print___024root           TOP;

    // CONSTRUCTORS
    Vcfg_print__Syms(VerilatedContext* contextp, const char* namep, Vcfg_print* modelp);
    ~Vcfg_print__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
