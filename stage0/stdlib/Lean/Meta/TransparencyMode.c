// Lean compiler output
// Module: Lean.Meta.TransparencyMode
// Imports: Init.Data.UInt.Basic
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
LEAN_EXPORT lean_object* l_Lean_Meta_TransparencyMode_lt___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint64_t l_Lean_Meta_TransparencyMode_hash(uint8_t);
static lean_object* l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0;
LEAN_EXPORT lean_object* l_Lean_Meta_TransparencyMode_instHashable__lean;
LEAN_EXPORT lean_object* l_Lean_Meta_TransparencyMode_hash___boxed(lean_object*);
LEAN_EXPORT uint8_t l_Lean_Meta_TransparencyMode_lt(uint8_t, uint8_t);
LEAN_EXPORT uint64_t l_Lean_Meta_TransparencyMode_hash(uint8_t x_1) {
_start:
{
switch (x_1) {
case 0:
{
uint64_t x_2; 
x_2 = 7;
return x_2;
}
case 1:
{
uint64_t x_3; 
x_3 = 11;
return x_3;
}
case 2:
{
uint64_t x_4; 
x_4 = 13;
return x_4;
}
default: 
{
uint64_t x_5; 
x_5 = 17;
return x_5;
}
}
}
}
LEAN_EXPORT lean_object* l_Lean_Meta_TransparencyMode_hash___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; uint64_t x_3; lean_object* x_4; 
x_2 = lean_unbox(x_1);
x_3 = l_Lean_Meta_TransparencyMode_hash(x_2);
x_4 = lean_box_uint64(x_3);
return x_4;
}
}
static lean_object* _init_l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_alloc_closure((void*)(l_Lean_Meta_TransparencyMode_hash___boxed), 1, 0);
return x_1;
}
}
static lean_object* _init_l_Lean_Meta_TransparencyMode_instHashable__lean() {
_start:
{
lean_object* x_1; 
x_1 = l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0;
return x_1;
}
}
LEAN_EXPORT uint8_t l_Lean_Meta_TransparencyMode_lt(uint8_t x_1, uint8_t x_2) {
_start:
{
switch (x_1) {
case 0:
{
uint8_t x_3; 
x_3 = 0;
return x_3;
}
case 1:
{
if (x_2 == 0)
{
uint8_t x_4; 
x_4 = 1;
return x_4;
}
else
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
}
case 2:
{
if (x_2 == 2)
{
uint8_t x_6; 
x_6 = 0;
return x_6;
}
else
{
uint8_t x_7; 
x_7 = 1;
return x_7;
}
}
default: 
{
switch (x_2) {
case 2:
{
uint8_t x_8; 
x_8 = 0;
return x_8;
}
case 3:
{
uint8_t x_9; 
x_9 = 0;
return x_9;
}
default: 
{
uint8_t x_10; 
x_10 = 1;
return x_10;
}
}
}
}
}
}
LEAN_EXPORT lean_object* l_Lean_Meta_TransparencyMode_lt___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = l_Lean_Meta_TransparencyMode_lt(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
lean_object* initialize_Init_Data_UInt_Basic(uint8_t builtin, lean_object*);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_Lean_Meta_TransparencyMode(uint8_t builtin, lean_object* w) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init_Data_UInt_Basic(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0 = _init_l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0();
lean_mark_persistent(l_Lean_Meta_TransparencyMode_instHashable__lean___closed__0);
l_Lean_Meta_TransparencyMode_instHashable__lean = _init_l_Lean_Meta_TransparencyMode_instHashable__lean();
lean_mark_persistent(l_Lean_Meta_TransparencyMode_instHashable__lean);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
