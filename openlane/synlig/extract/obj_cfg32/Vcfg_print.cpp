// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vcfg_print__pch.h"

//============================================================
// Constructors

Vcfg_print::Vcfg_print(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vcfg_print__Syms(contextp(), _vcname__, this)}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vcfg_print::Vcfg_print(const char* _vcname__)
    : Vcfg_print(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vcfg_print::~Vcfg_print() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vcfg_print___024root___eval_debug_assertions(Vcfg_print___024root* vlSelf);
#endif  // VL_DEBUG
void Vcfg_print___024root___eval_static(Vcfg_print___024root* vlSelf);
void Vcfg_print___024root___eval_initial(Vcfg_print___024root* vlSelf);
void Vcfg_print___024root___eval_settle(Vcfg_print___024root* vlSelf);
void Vcfg_print___024root___eval(Vcfg_print___024root* vlSelf);

void Vcfg_print::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vcfg_print::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vcfg_print___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vcfg_print___024root___eval_static(&(vlSymsp->TOP));
        Vcfg_print___024root___eval_initial(&(vlSymsp->TOP));
        Vcfg_print___024root___eval_settle(&(vlSymsp->TOP));
        vlSymsp->__Vm_didInit = true;
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vcfg_print___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vcfg_print::eventsPending() { return false; }

uint64_t Vcfg_print::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vcfg_print::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vcfg_print___024root___eval_final(Vcfg_print___024root* vlSelf);

VL_ATTR_COLD void Vcfg_print::final() {
    Vcfg_print___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vcfg_print::hierName() const { return vlSymsp->name(); }
const char* Vcfg_print::modelName() const { return "Vcfg_print"; }
unsigned Vcfg_print::threads() const { return 1; }
void Vcfg_print::prepareClone() const { contextp()->prepareClone(); }
void Vcfg_print::atClone() const {
    contextp()->threadPoolpOnClone();
}
