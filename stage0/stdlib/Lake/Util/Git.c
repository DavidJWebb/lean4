// Lean compiler output
// Module: Lake.Util.Git
// Imports: Lake.Util.Proc Lake.Util.Lift
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
LEAN_EXPORT lean_object* l_Lake_GitRepo_getFilteredRemoteUrl_x3f(lean_object*, lean_object*, lean_object*);
lean_object* lean_string_utf8_extract(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0(uint8_t, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_testGit(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_checkoutBranch___closed__3;
uint32_t lean_string_utf8_get(lean_object*, lean_object*);
lean_object* lean_mk_empty_array_with_capacity(lean_object*);
static lean_object* l_Lake_GitRepo_resolveRevision_x3f___closed__4;
static lean_object* l_Lake_GitRepo_revisionExists___closed__1;
LEAN_EXPORT lean_object* l_Lake_instToStringGitRepo;
lean_object* lean_array_push(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_instCoeFilePathGitRepo___lam__0(lean_object*);
static lean_object* l_Lake_GitRepo_findTag_x3f___closed__0;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__2;
static lean_object* l_Lake_GitRepo_getRemoteUrl_x3f___closed__2;
static lean_object* l_Lake_GitRepo_insideWorkTree___closed__2;
static lean_object* l_Lake_GitRepo_hasNoDiff___closed__0;
static lean_object* l_Lake_GitRepo_quietInit___closed__4;
static lean_object* l_Lake_GitRepo_captureGit_x3f___closed__0;
static lean_object* l_Lake_GitRepo_fetch___closed__3;
LEAN_EXPORT lean_object* l_Lake_GitRepo_captureGit_x3f(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_getHeadRevision_x3f___closed__1;
static lean_object* l_Lake_GitRepo_branchExists___closed__0;
static lean_object* l_Lake_GitRepo_cwd___closed__0;
LEAN_EXPORT lean_object* l_Lake_Git_isFullObjectName___boxed(lean_object*);
static lean_object* l_Lake_GitRepo_findTag_x3f___closed__2;
static lean_object* l_Lake_GitRepo_fetch___closed__1;
static lean_object* l_Lake_GitRepo_checkoutDetach___closed__3;
static lean_object* l_Lake_GitRepo_getHeadRevision_x3f___closed__0;
lean_object* lean_string_utf8_byte_size(lean_object*);
static lean_object* l_Lake_GitRepo_resolveRevision_x3f___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_resolveRemoteRevision(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_getTags___closed__2;
static lean_object* l_Lake_GitRepo_quietInit___closed__1;
static lean_object* l_Lake_GitRepo_quietInit___closed__3;
static lean_object* l_Lake_Git_upstreamBranch___closed__0;
static lean_object* l_Lake_GitRepo_clone___closed__0;
lean_object* l_Lake_captureProc_x3f(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_clone___closed__2;
lean_object* lean_string_utf8_next(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_fetch___closed__6;
static lean_object* l_Lake_GitRepo_fetch___closed__4;
static lean_object* l_Lake_GitRepo_clone___closed__1;
lean_object* l_System_FilePath_isDir(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_instCoeFilePathGitRepo;
static lean_object* l_Lake_GitRepo_fetch___closed__5;
uint8_t lean_uint32_dec_le(uint32_t, uint32_t);
LEAN_EXPORT lean_object* l_Lake_GitRepo_branchExists___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_cwd;
static lean_object* l_Lake_GitRepo_hasNoDiff___closed__3;
LEAN_EXPORT uint8_t l_Lake_GitRepo_getTags___lam__0(uint32_t);
LEAN_EXPORT lean_object* l_Lake_GitRepo_branchExists(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_findTag_x3f___closed__3;
static lean_object* l_Lake_GitRepo_getHeadRevision___closed__0;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__5;
static lean_object* l_Lake_GitRepo_getRemoteUrl_x3f___closed__1;
static lean_object* l_Lake_GitRepo_branchExists___closed__2;
static lean_object* l_Lake_GitRepo_checkoutDetach___closed__0;
LEAN_EXPORT lean_object* l_Lake_Git_filterUrl_x3f(lean_object*);
static lean_object* l_Lake_GitRepo_checkoutBranch___closed__1;
LEAN_EXPORT lean_object* l_Lake_GitRepo_clone(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_resolveRevision_x3f(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_findTag_x3f___closed__4;
LEAN_EXPORT lean_object* l_Lake_GitRepo_dirExists(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_branchExists___closed__1;
LEAN_EXPORT lean_object* l_Lake_GitRepo_findRemoteRevision(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_hasNoDiff(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_dirExists___boxed(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_getRemoteUrl_x3f___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_revisionExists(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_getHeadRevision(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t l_Lake_Git_isFullObjectName(lean_object*);
lean_object* l_Lake_testProc(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_Git_defaultRemote;
static lean_object* l_Lake_GitRepo_getRemoteUrl_x3f___closed__3;
static lean_object* l_Lake_GitRepo_branchExists___closed__3;
static lean_object* l_Lake_GitRepo_resolveRemoteRevision___closed__2;
static lean_object* l_Lake_GitRepo_resolveRemoteRevision___closed__0;
lean_object* l_Substring_nextn(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_fetch(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_findTag_x3f(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_checkoutDetach(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_GitRepo_getHeadRevision_x3f(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_getTags___closed__1;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__3;
static lean_object* l_Lake_GitRepo_resolveRemoteRevision___closed__1;
lean_object* lean_string_length(lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_hasNoDiff___closed__2;
static lean_object* l_Lake_GitRepo_insideWorkTree___closed__3;
LEAN_EXPORT lean_object* l_Lake_GitRepo_getTags___lam__0___boxed(lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_checkoutBranch___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_execGit(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_uint32_dec_eq(uint32_t, uint32_t);
static lean_object* l_Lake_GitRepo_insideWorkTree___closed__1;
lean_object* l_Substring_prevn(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_captureGit_x3f___closed__1;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__0;
static lean_object* l_Lake_GitRepo_resolveRevision_x3f___closed__1;
static lean_object* l_Lake_GitRepo_revisionExists___closed__2;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__4;
static lean_object* l_Lake_GitRepo_fetch___closed__0;
lean_object* l_Lake_proc(lean_object*, uint8_t, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_hasNoDiff___closed__1;
LEAN_EXPORT lean_object* l_Lake_GitRepo_hasDiff(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_checkoutBranch___closed__2;
static lean_object* l_Lake_GitRepo_resolveRevision_x3f___closed__3;
static lean_object* l_Lake_GitRepo_quietInit___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_checkoutBranch(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t l_Substring_beq(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_insideWorkTree___closed__0;
static lean_object* l_Lake_GitRepo_resolveRevision_x3f___closed__2;
static lean_object* l_Lake_GitRepo_checkoutDetach___closed__2;
LEAN_EXPORT lean_object* l_Lake_GitRepo_getTags(lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_getTags___closed__0;
lean_object* lean_string_append(lean_object*, lean_object*);
static lean_object* l_Lake_Git_defaultRemote___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_getRemoteUrl_x3f(lean_object*, lean_object*, lean_object*);
lean_object* lean_array_get_size(lean_object*);
static lean_object* l_Lake_GitRepo_checkoutDetach___closed__1;
static lean_object* l_Lake_GitRepo_quietInit___closed__2;
LEAN_EXPORT lean_object* l_Lake_GitRepo_quietInit(lean_object*, lean_object*, lean_object*);
static lean_object* l_Lake_GitRepo_findTag_x3f___closed__1;
static lean_object* l_Lake_GitRepo_revisionExists___closed__0;
static lean_object* l_Lake_GitRepo_fetch___closed__2;
static lean_object* l_Lake_Git_filterUrl_x3f___closed__1;
lean_object* l_String_split(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_instCoeFilePathGitRepo___lam__0___boxed(lean_object*);
static lean_object* l_Lake_instToStringGitRepo___closed__0;
LEAN_EXPORT lean_object* l_Lake_GitRepo_insideWorkTree(lean_object*, lean_object*);
LEAN_EXPORT lean_object* l_Lake_Git_upstreamBranch;
static lean_object* _init_l_Lake_Git_defaultRemote___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("origin", 6, 6);
return x_1;
}
}
static lean_object* _init_l_Lake_Git_defaultRemote() {
_start:
{
lean_object* x_1; 
x_1 = l_Lake_Git_defaultRemote___closed__0;
return x_1;
}
}
static lean_object* _init_l_Lake_Git_upstreamBranch___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("master", 6, 6);
return x_1;
}
}
static lean_object* _init_l_Lake_Git_upstreamBranch() {
_start:
{
lean_object* x_1; 
x_1 = l_Lake_Git_upstreamBranch___closed__0;
return x_1;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("git", 3, 3);
return x_1;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = l_Lake_Git_filterUrl_x3f___closed__0;
x_2 = lean_string_utf8_byte_size(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; lean_object* x_4; 
x_1 = l_Lake_Git_filterUrl_x3f___closed__1;
x_2 = lean_unsigned_to_nat(0u);
x_3 = l_Lake_Git_filterUrl_x3f___closed__0;
x_4 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_4, 0, x_3);
lean_ctor_set(x_4, 1, x_2);
lean_ctor_set(x_4, 2, x_1);
return x_4;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__3() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(".git", 4, 4);
return x_1;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = l_Lake_Git_filterUrl_x3f___closed__3;
x_2 = lean_string_utf8_byte_size(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_Git_filterUrl_x3f___closed__5() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; lean_object* x_4; 
x_1 = l_Lake_Git_filterUrl_x3f___closed__4;
x_2 = lean_unsigned_to_nat(0u);
x_3 = l_Lake_Git_filterUrl_x3f___closed__3;
x_4 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_4, 0, x_3);
lean_ctor_set(x_4, 1, x_2);
lean_ctor_set(x_4, 2, x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* l_Lake_Git_filterUrl_x3f(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_string_utf8_byte_size(x_1);
lean_inc(x_3);
lean_inc_ref(x_1);
x_4 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_4, 0, x_1);
lean_ctor_set(x_4, 1, x_2);
lean_ctor_set(x_4, 2, x_3);
x_5 = lean_unsigned_to_nat(3u);
x_6 = l_Substring_nextn(x_4, x_5, x_2);
lean_inc_ref(x_1);
x_7 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_7, 0, x_1);
lean_ctor_set(x_7, 1, x_2);
lean_ctor_set(x_7, 2, x_6);
x_8 = l_Lake_Git_filterUrl_x3f___closed__2;
x_9 = l_Substring_beq(x_7, x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_10 = lean_unsigned_to_nat(4u);
lean_inc(x_3);
x_11 = l_Substring_prevn(x_4, x_10, x_3);
lean_dec_ref(x_4);
lean_inc(x_11);
lean_inc_ref(x_1);
x_12 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_12, 0, x_1);
lean_ctor_set(x_12, 1, x_11);
lean_ctor_set(x_12, 2, x_3);
x_13 = l_Lake_Git_filterUrl_x3f___closed__5;
x_14 = l_Substring_beq(x_12, x_13);
if (x_14 == 0)
{
lean_object* x_15; 
lean_dec(x_11);
x_15 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_15, 0, x_1);
return x_15;
}
else
{
lean_object* x_16; lean_object* x_17; 
x_16 = lean_string_utf8_extract(x_1, x_2, x_11);
lean_dec(x_11);
lean_dec_ref(x_1);
x_17 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_17, 0, x_16);
return x_17;
}
}
else
{
lean_object* x_18; 
lean_dec_ref(x_4);
lean_dec(x_3);
lean_dec_ref(x_1);
x_18 = lean_box(0);
return x_18;
}
}
}
LEAN_EXPORT uint8_t l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0(uint8_t x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_8; uint8_t x_10; 
x_10 = lean_nat_dec_lt(x_4, x_3);
if (x_10 == 0)
{
lean_dec(x_4);
return x_10;
}
else
{
uint32_t x_11; uint8_t x_12; uint32_t x_18; uint8_t x_19; 
x_11 = lean_string_utf8_get(x_2, x_4);
x_18 = 48;
x_19 = lean_uint32_dec_le(x_18, x_11);
if (x_19 == 0)
{
x_12 = x_19;
goto block_17;
}
else
{
uint32_t x_20; uint8_t x_21; 
x_20 = 57;
x_21 = lean_uint32_dec_le(x_11, x_20);
x_12 = x_21;
goto block_17;
}
block_17:
{
if (x_12 == 0)
{
uint32_t x_13; uint8_t x_14; 
x_13 = 97;
x_14 = lean_uint32_dec_le(x_13, x_11);
if (x_14 == 0)
{
x_8 = x_14;
goto block_9;
}
else
{
uint32_t x_15; uint8_t x_16; 
x_15 = 102;
x_16 = lean_uint32_dec_le(x_11, x_15);
x_8 = x_16;
goto block_9;
}
}
else
{
goto block_7;
}
}
}
block_7:
{
lean_object* x_5; 
x_5 = lean_string_utf8_next(x_2, x_4);
lean_dec(x_4);
x_4 = x_5;
goto _start;
}
block_9:
{
if (x_8 == 0)
{
if (x_1 == 0)
{
goto block_7;
}
else
{
lean_dec(x_4);
return x_1;
}
}
else
{
goto block_7;
}
}
}
}
LEAN_EXPORT uint8_t l_Lake_Git_isFullObjectName(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; uint8_t x_4; 
x_2 = lean_string_length(x_1);
x_3 = lean_unsigned_to_nat(40u);
x_4 = lean_nat_dec_eq(x_2, x_3);
lean_dec(x_2);
if (x_4 == 0)
{
return x_4;
}
else
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_5 = lean_string_utf8_byte_size(x_1);
x_6 = lean_unsigned_to_nat(0u);
x_7 = l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0(x_4, x_1, x_5, x_6);
lean_dec(x_5);
if (x_7 == 0)
{
return x_4;
}
else
{
uint8_t x_8; 
x_8 = 0;
return x_8;
}
}
}
}
LEAN_EXPORT lean_object* l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; uint8_t x_6; lean_object* x_7; 
x_5 = lean_unbox(x_1);
x_6 = l_String_anyAux___at___Lake_Git_isFullObjectName_spec__0(x_5, x_2, x_3, x_4);
lean_dec(x_3);
lean_dec_ref(x_2);
x_7 = lean_box(x_6);
return x_7;
}
}
LEAN_EXPORT lean_object* l_Lake_Git_isFullObjectName___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = l_Lake_Git_isFullObjectName(x_1);
lean_dec_ref(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_instCoeFilePathGitRepo___lam__0(lean_object* x_1) {
_start:
{
lean_inc_ref(x_1);
return x_1;
}
}
static lean_object* _init_l_Lake_instCoeFilePathGitRepo() {
_start:
{
lean_object* x_1; 
x_1 = lean_alloc_closure((void*)(l_Lake_instCoeFilePathGitRepo___lam__0___boxed), 1, 0);
return x_1;
}
}
LEAN_EXPORT lean_object* l_Lake_instCoeFilePathGitRepo___lam__0___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = l_Lake_instCoeFilePathGitRepo___lam__0(x_1);
lean_dec_ref(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_instToStringGitRepo___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_alloc_closure((void*)(l_Lake_instCoeFilePathGitRepo___lam__0___boxed), 1, 0);
return x_1;
}
}
static lean_object* _init_l_Lake_instToStringGitRepo() {
_start:
{
lean_object* x_1; 
x_1 = l_Lake_instToStringGitRepo___closed__0;
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_cwd___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(".", 1, 1);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_cwd() {
_start:
{
lean_object* x_1; 
x_1 = l_Lake_GitRepo_cwd___closed__0;
return x_1;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_dirExists(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = l_System_FilePath_isDir(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_dirExists___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = l_Lake_GitRepo_dirExists(x_1, x_2);
lean_dec_ref(x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_captureGit_x3f___closed__0() {
_start:
{
uint8_t x_1; lean_object* x_2; 
x_1 = 1;
x_2 = lean_alloc_ctor(0, 0, 3);
lean_ctor_set_uint8(x_2, 0, x_1);
lean_ctor_set_uint8(x_2, 1, x_1);
lean_ctor_set_uint8(x_2, 2, x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_GitRepo_captureGit_x3f___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_captureGit_x3f(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_2);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_1);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_captureProc_x3f(x_10, x_3);
return x_11;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_execGit(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; 
x_5 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_6 = l_Lake_Git_filterUrl_x3f___closed__0;
x_7 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_7, 0, x_2);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_9 = 1;
x_10 = 0;
x_11 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_11, 0, x_5);
lean_ctor_set(x_11, 1, x_6);
lean_ctor_set(x_11, 2, x_1);
lean_ctor_set(x_11, 3, x_7);
lean_ctor_set(x_11, 4, x_8);
lean_ctor_set_uint8(x_11, sizeof(void*)*5, x_9);
lean_ctor_set_uint8(x_11, sizeof(void*)*5 + 1, x_10);
x_12 = l_Lake_proc(x_11, x_9, x_3, x_4);
return x_12;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_testGit(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_2);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_1);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_testProc(x_10, x_3);
return x_11;
}
}
static lean_object* _init_l_Lake_GitRepo_clone___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("clone", 5, 5);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_clone___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(3u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_GitRepo_clone___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_clone___closed__0;
x_2 = l_Lake_GitRepo_clone___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_clone(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_5 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_6 = l_Lake_Git_filterUrl_x3f___closed__0;
x_7 = l_Lake_GitRepo_clone___closed__2;
x_8 = lean_array_push(x_7, x_1);
x_9 = lean_array_push(x_8, x_2);
x_10 = lean_box(0);
x_11 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_12 = 1;
x_13 = 0;
x_14 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_14, 0, x_5);
lean_ctor_set(x_14, 1, x_6);
lean_ctor_set(x_14, 2, x_9);
lean_ctor_set(x_14, 3, x_10);
lean_ctor_set(x_14, 4, x_11);
lean_ctor_set_uint8(x_14, sizeof(void*)*5, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*5 + 1, x_13);
x_15 = l_Lake_proc(x_14, x_12, x_3, x_4);
return x_15;
}
}
static lean_object* _init_l_Lake_GitRepo_quietInit___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("init", 4, 4);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_quietInit___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("-q", 2, 2);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_quietInit___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(2u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_GitRepo_quietInit___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_quietInit___closed__0;
x_2 = l_Lake_GitRepo_quietInit___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_quietInit___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_quietInit___closed__1;
x_2 = l_Lake_GitRepo_quietInit___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_quietInit(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; 
x_4 = l_Lake_GitRepo_quietInit___closed__4;
x_5 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_6 = l_Lake_Git_filterUrl_x3f___closed__0;
x_7 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_7, 0, x_1);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_9 = 1;
x_10 = 0;
x_11 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_11, 0, x_5);
lean_ctor_set(x_11, 1, x_6);
lean_ctor_set(x_11, 2, x_4);
lean_ctor_set(x_11, 3, x_7);
lean_ctor_set(x_11, 4, x_8);
lean_ctor_set_uint8(x_11, sizeof(void*)*5, x_9);
lean_ctor_set_uint8(x_11, sizeof(void*)*5 + 1, x_10);
x_12 = l_Lake_proc(x_11, x_9, x_2, x_3);
return x_12;
}
}
static lean_object* _init_l_Lake_GitRepo_insideWorkTree___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("rev-parse", 9, 9);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_insideWorkTree___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--is-inside-work-tree", 21, 21);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_insideWorkTree___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_insideWorkTree___closed__0;
x_2 = l_Lake_GitRepo_quietInit___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_insideWorkTree___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_insideWorkTree___closed__1;
x_2 = l_Lake_GitRepo_insideWorkTree___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_insideWorkTree(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_3 = l_Lake_GitRepo_insideWorkTree___closed__3;
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_3);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_testProc(x_10, x_2);
return x_11;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("fetch", 5, 5);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--tags", 6, 6);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__2() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--force", 7, 7);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(4u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_fetch___closed__0;
x_2 = l_Lake_GitRepo_fetch___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__5() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_fetch___closed__1;
x_2 = l_Lake_GitRepo_fetch___closed__4;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_fetch___closed__6() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_fetch___closed__2;
x_2 = l_Lake_GitRepo_fetch___closed__5;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_fetch(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; uint8_t x_12; lean_object* x_13; lean_object* x_14; 
x_5 = l_Lake_GitRepo_fetch___closed__6;
x_6 = lean_array_push(x_5, x_2);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_8 = l_Lake_Git_filterUrl_x3f___closed__0;
x_9 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_9, 0, x_1);
x_10 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_11 = 1;
x_12 = 0;
x_13 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_13, 0, x_7);
lean_ctor_set(x_13, 1, x_8);
lean_ctor_set(x_13, 2, x_6);
lean_ctor_set(x_13, 3, x_9);
lean_ctor_set(x_13, 4, x_10);
lean_ctor_set_uint8(x_13, sizeof(void*)*5, x_11);
lean_ctor_set_uint8(x_13, sizeof(void*)*5 + 1, x_12);
x_14 = l_Lake_proc(x_13, x_11, x_3, x_4);
return x_14;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutBranch___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("checkout", 8, 8);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutBranch___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("-B", 2, 2);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutBranch___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_checkoutBranch___closed__0;
x_2 = l_Lake_GitRepo_clone___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutBranch___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_checkoutBranch___closed__1;
x_2 = l_Lake_GitRepo_checkoutBranch___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_checkoutBranch(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; uint8_t x_12; lean_object* x_13; lean_object* x_14; 
x_5 = l_Lake_GitRepo_checkoutBranch___closed__3;
x_6 = lean_array_push(x_5, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_8 = l_Lake_Git_filterUrl_x3f___closed__0;
x_9 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_9, 0, x_2);
x_10 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_11 = 1;
x_12 = 0;
x_13 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_13, 0, x_7);
lean_ctor_set(x_13, 1, x_8);
lean_ctor_set(x_13, 2, x_6);
lean_ctor_set(x_13, 3, x_9);
lean_ctor_set(x_13, 4, x_10);
lean_ctor_set_uint8(x_13, sizeof(void*)*5, x_11);
lean_ctor_set_uint8(x_13, sizeof(void*)*5 + 1, x_12);
x_14 = l_Lake_proc(x_13, x_11, x_3, x_4);
return x_14;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutDetach___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--detach", 8, 8);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutDetach___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--", 2, 2);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutDetach___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_checkoutBranch___closed__0;
x_2 = l_Lake_GitRepo_fetch___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_checkoutDetach___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_checkoutDetach___closed__0;
x_2 = l_Lake_GitRepo_checkoutDetach___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_checkoutDetach(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; 
x_5 = l_Lake_GitRepo_checkoutDetach___closed__1;
x_6 = l_Lake_GitRepo_checkoutDetach___closed__3;
x_7 = lean_array_push(x_6, x_1);
x_8 = lean_array_push(x_7, x_5);
x_9 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_10 = l_Lake_Git_filterUrl_x3f___closed__0;
x_11 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_11, 0, x_2);
x_12 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_13 = 1;
x_14 = 0;
x_15 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_15, 0, x_9);
lean_ctor_set(x_15, 1, x_10);
lean_ctor_set(x_15, 2, x_8);
lean_ctor_set(x_15, 3, x_11);
lean_ctor_set(x_15, 4, x_12);
lean_ctor_set_uint8(x_15, sizeof(void*)*5, x_13);
lean_ctor_set_uint8(x_15, sizeof(void*)*5 + 1, x_14);
x_16 = l_Lake_proc(x_15, x_13, x_3, x_4);
return x_16;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRevision_x3f___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--verify", 8, 8);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRevision_x3f___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--end-of-options", 16, 16);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRevision_x3f___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_insideWorkTree___closed__0;
x_2 = l_Lake_GitRepo_fetch___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRevision_x3f___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_resolveRevision_x3f___closed__0;
x_2 = l_Lake_GitRepo_resolveRevision_x3f___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRevision_x3f___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_resolveRevision_x3f___closed__1;
x_2 = l_Lake_GitRepo_resolveRevision_x3f___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_resolveRevision_x3f(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; 
x_4 = l_Lake_GitRepo_resolveRevision_x3f___closed__4;
x_5 = lean_array_push(x_4, x_1);
x_6 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_7 = l_Lake_Git_filterUrl_x3f___closed__0;
x_8 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_8, 0, x_2);
x_9 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_10 = 1;
x_11 = 0;
x_12 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_12, 0, x_6);
lean_ctor_set(x_12, 1, x_7);
lean_ctor_set(x_12, 2, x_5);
lean_ctor_set(x_12, 3, x_8);
lean_ctor_set(x_12, 4, x_9);
lean_ctor_set_uint8(x_12, sizeof(void*)*5, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*5 + 1, x_11);
x_13 = l_Lake_captureProc_x3f(x_12, x_3);
return x_13;
}
}
static lean_object* _init_l_Lake_GitRepo_getHeadRevision_x3f___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("HEAD", 4, 4);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_getHeadRevision_x3f___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_getHeadRevision_x3f___closed__0;
x_2 = l_Lake_GitRepo_resolveRevision_x3f___closed__4;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getHeadRevision_x3f(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_3 = l_Lake_GitRepo_getHeadRevision_x3f___closed__1;
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_3);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_captureProc_x3f(x_10, x_2);
return x_11;
}
}
static lean_object* _init_l_Lake_GitRepo_getHeadRevision___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(": could not resolve 'HEAD' to a commit; the repository may be corrupt, so you may need to remove it and try again", 113, 113);
return x_1;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getHeadRevision(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; 
x_4 = l_Lake_GitRepo_getHeadRevision_x3f___closed__1;
x_5 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_6 = l_Lake_Git_filterUrl_x3f___closed__0;
lean_inc_ref(x_1);
x_7 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_7, 0, x_1);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_9 = 1;
x_10 = 0;
x_11 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_11, 0, x_5);
lean_ctor_set(x_11, 1, x_6);
lean_ctor_set(x_11, 2, x_4);
lean_ctor_set(x_11, 3, x_7);
lean_ctor_set(x_11, 4, x_8);
lean_ctor_set_uint8(x_11, sizeof(void*)*5, x_9);
lean_ctor_set_uint8(x_11, sizeof(void*)*5 + 1, x_10);
x_12 = l_Lake_captureProc_x3f(x_11, x_3);
x_13 = lean_ctor_get(x_12, 0);
lean_inc(x_13);
if (lean_obj_tag(x_13) == 0)
{
uint8_t x_14; 
x_14 = !lean_is_exclusive(x_12);
if (x_14 == 0)
{
lean_object* x_15; lean_object* x_16; lean_object* x_17; uint8_t x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; 
x_15 = lean_ctor_get(x_12, 0);
lean_dec(x_15);
x_16 = l_Lake_GitRepo_getHeadRevision___closed__0;
x_17 = lean_string_append(x_1, x_16);
x_18 = 3;
x_19 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set_uint8(x_19, sizeof(void*)*1, x_18);
x_20 = lean_array_get_size(x_2);
x_21 = lean_array_push(x_2, x_19);
x_22 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
lean_ctor_set(x_12, 0, x_22);
return x_12;
}
else
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; uint8_t x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; 
x_23 = lean_ctor_get(x_12, 1);
lean_inc(x_23);
lean_dec(x_12);
x_24 = l_Lake_GitRepo_getHeadRevision___closed__0;
x_25 = lean_string_append(x_1, x_24);
x_26 = 3;
x_27 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_27, 0, x_25);
lean_ctor_set_uint8(x_27, sizeof(void*)*1, x_26);
x_28 = lean_array_get_size(x_2);
x_29 = lean_array_push(x_2, x_27);
x_30 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set(x_30, 1, x_29);
x_31 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set(x_31, 1, x_23);
return x_31;
}
}
else
{
uint8_t x_32; 
lean_dec_ref(x_1);
x_32 = !lean_is_exclusive(x_12);
if (x_32 == 0)
{
lean_object* x_33; lean_object* x_34; lean_object* x_35; 
x_33 = lean_ctor_get(x_12, 0);
lean_dec(x_33);
x_34 = lean_ctor_get(x_13, 0);
lean_inc(x_34);
lean_dec_ref(x_13);
x_35 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_35, 0, x_34);
lean_ctor_set(x_35, 1, x_2);
lean_ctor_set(x_12, 0, x_35);
return x_12;
}
else
{
lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; 
x_36 = lean_ctor_get(x_12, 1);
lean_inc(x_36);
lean_dec(x_12);
x_37 = lean_ctor_get(x_13, 0);
lean_inc(x_37);
lean_dec_ref(x_13);
x_38 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_2);
x_39 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_36);
return x_39;
}
}
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRemoteRevision___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("/", 1, 1);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRemoteRevision___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked(": revision not found '", 22, 22);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_resolveRemoteRevision___closed__2() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("'", 1, 1);
return x_1;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_resolveRemoteRevision(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; 
x_6 = l_Lake_Git_isFullObjectName(x_1);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; uint8_t x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; 
x_7 = l_Lake_GitRepo_resolveRemoteRevision___closed__0;
x_8 = lean_string_append(x_2, x_7);
x_9 = lean_string_append(x_8, x_1);
x_10 = l_Lake_GitRepo_resolveRevision_x3f___closed__4;
x_11 = lean_array_push(x_10, x_9);
x_12 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_13 = l_Lake_Git_filterUrl_x3f___closed__0;
lean_inc_ref(x_3);
x_14 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_14, 0, x_3);
x_15 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_16 = 1;
lean_inc_ref(x_14);
x_17 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_17, 0, x_12);
lean_ctor_set(x_17, 1, x_13);
lean_ctor_set(x_17, 2, x_11);
lean_ctor_set(x_17, 3, x_14);
lean_ctor_set(x_17, 4, x_15);
lean_ctor_set_uint8(x_17, sizeof(void*)*5, x_16);
lean_ctor_set_uint8(x_17, sizeof(void*)*5 + 1, x_6);
x_18 = l_Lake_captureProc_x3f(x_17, x_5);
x_19 = lean_ctor_get(x_18, 0);
lean_inc(x_19);
if (lean_obj_tag(x_19) == 0)
{
lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; 
x_20 = lean_ctor_get(x_18, 1);
lean_inc(x_20);
lean_dec_ref(x_18);
lean_inc_ref(x_1);
x_21 = lean_array_push(x_10, x_1);
x_22 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_22, 0, x_12);
lean_ctor_set(x_22, 1, x_13);
lean_ctor_set(x_22, 2, x_21);
lean_ctor_set(x_22, 3, x_14);
lean_ctor_set(x_22, 4, x_15);
lean_ctor_set_uint8(x_22, sizeof(void*)*5, x_16);
lean_ctor_set_uint8(x_22, sizeof(void*)*5 + 1, x_6);
x_23 = l_Lake_captureProc_x3f(x_22, x_20);
x_24 = lean_ctor_get(x_23, 0);
lean_inc(x_24);
if (lean_obj_tag(x_24) == 0)
{
uint8_t x_25; 
x_25 = !lean_is_exclusive(x_23);
if (x_25 == 0)
{
lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; uint8_t x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_26 = lean_ctor_get(x_23, 0);
lean_dec(x_26);
x_27 = l_Lake_GitRepo_resolveRemoteRevision___closed__1;
x_28 = lean_string_append(x_3, x_27);
x_29 = lean_string_append(x_28, x_1);
lean_dec_ref(x_1);
x_30 = l_Lake_GitRepo_resolveRemoteRevision___closed__2;
x_31 = lean_string_append(x_29, x_30);
x_32 = 3;
x_33 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_33, 0, x_31);
lean_ctor_set_uint8(x_33, sizeof(void*)*1, x_32);
x_34 = lean_array_get_size(x_4);
x_35 = lean_array_push(x_4, x_33);
x_36 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
lean_ctor_set(x_23, 0, x_36);
return x_23;
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; uint8_t x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; 
x_37 = lean_ctor_get(x_23, 1);
lean_inc(x_37);
lean_dec(x_23);
x_38 = l_Lake_GitRepo_resolveRemoteRevision___closed__1;
x_39 = lean_string_append(x_3, x_38);
x_40 = lean_string_append(x_39, x_1);
lean_dec_ref(x_1);
x_41 = l_Lake_GitRepo_resolveRemoteRevision___closed__2;
x_42 = lean_string_append(x_40, x_41);
x_43 = 3;
x_44 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_44, 0, x_42);
lean_ctor_set_uint8(x_44, sizeof(void*)*1, x_43);
x_45 = lean_array_get_size(x_4);
x_46 = lean_array_push(x_4, x_44);
x_47 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_47, 0, x_45);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_48, 0, x_47);
lean_ctor_set(x_48, 1, x_37);
return x_48;
}
}
else
{
uint8_t x_49; 
lean_dec_ref(x_3);
lean_dec_ref(x_1);
x_49 = !lean_is_exclusive(x_23);
if (x_49 == 0)
{
lean_object* x_50; lean_object* x_51; lean_object* x_52; 
x_50 = lean_ctor_get(x_23, 0);
lean_dec(x_50);
x_51 = lean_ctor_get(x_24, 0);
lean_inc(x_51);
lean_dec_ref(x_24);
x_52 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_52, 0, x_51);
lean_ctor_set(x_52, 1, x_4);
lean_ctor_set(x_23, 0, x_52);
return x_23;
}
else
{
lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; 
x_53 = lean_ctor_get(x_23, 1);
lean_inc(x_53);
lean_dec(x_23);
x_54 = lean_ctor_get(x_24, 0);
lean_inc(x_54);
lean_dec_ref(x_24);
x_55 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set(x_55, 1, x_4);
x_56 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_56, 0, x_55);
lean_ctor_set(x_56, 1, x_53);
return x_56;
}
}
}
else
{
uint8_t x_57; 
lean_dec_ref(x_14);
lean_dec_ref(x_3);
lean_dec_ref(x_1);
x_57 = !lean_is_exclusive(x_18);
if (x_57 == 0)
{
lean_object* x_58; lean_object* x_59; lean_object* x_60; 
x_58 = lean_ctor_get(x_18, 0);
lean_dec(x_58);
x_59 = lean_ctor_get(x_19, 0);
lean_inc(x_59);
lean_dec_ref(x_19);
x_60 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_60, 0, x_59);
lean_ctor_set(x_60, 1, x_4);
lean_ctor_set(x_18, 0, x_60);
return x_18;
}
else
{
lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; 
x_61 = lean_ctor_get(x_18, 1);
lean_inc(x_61);
lean_dec(x_18);
x_62 = lean_ctor_get(x_19, 0);
lean_inc(x_62);
lean_dec_ref(x_19);
x_63 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set(x_63, 1, x_4);
x_64 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_64, 0, x_63);
lean_ctor_set(x_64, 1, x_61);
return x_64;
}
}
}
else
{
lean_object* x_65; lean_object* x_66; 
lean_dec_ref(x_3);
lean_dec_ref(x_2);
x_65 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_65, 0, x_1);
lean_ctor_set(x_65, 1, x_4);
x_66 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_66, 0, x_65);
lean_ctor_set(x_66, 1, x_5);
return x_66;
}
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_findRemoteRevision(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_6 = l_Lake_GitRepo_fetch___closed__6;
lean_inc_ref(x_3);
x_7 = lean_array_push(x_6, x_3);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_9 = l_Lake_Git_filterUrl_x3f___closed__0;
lean_inc_ref(x_1);
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_1);
x_11 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_12 = 1;
x_13 = 0;
x_14 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_14, 0, x_8);
lean_ctor_set(x_14, 1, x_9);
lean_ctor_set(x_14, 2, x_7);
lean_ctor_set(x_14, 3, x_10);
lean_ctor_set(x_14, 4, x_11);
lean_ctor_set_uint8(x_14, sizeof(void*)*5, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*5 + 1, x_13);
x_15 = l_Lake_proc(x_14, x_12, x_4, x_5);
x_16 = lean_ctor_get(x_15, 0);
lean_inc(x_16);
if (lean_obj_tag(x_16) == 0)
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; 
x_17 = lean_ctor_get(x_15, 1);
lean_inc(x_17);
lean_dec_ref(x_15);
x_18 = lean_ctor_get(x_16, 1);
lean_inc(x_18);
lean_dec_ref(x_16);
x_19 = l_Lake_Git_upstreamBranch___closed__0;
x_20 = l_Lake_GitRepo_resolveRemoteRevision(x_19, x_3, x_1, x_18, x_17);
return x_20;
}
else
{
lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; 
x_21 = lean_ctor_get(x_15, 1);
lean_inc(x_21);
lean_dec_ref(x_15);
x_22 = lean_ctor_get(x_16, 1);
lean_inc(x_22);
lean_dec_ref(x_16);
x_23 = lean_ctor_get(x_2, 0);
lean_inc(x_23);
lean_dec_ref(x_2);
x_24 = l_Lake_GitRepo_resolveRemoteRevision(x_23, x_3, x_1, x_22, x_21);
return x_24;
}
}
else
{
uint8_t x_25; 
lean_dec_ref(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
x_25 = !lean_is_exclusive(x_15);
if (x_25 == 0)
{
lean_object* x_26; uint8_t x_27; 
x_26 = lean_ctor_get(x_15, 0);
lean_dec(x_26);
x_27 = !lean_is_exclusive(x_16);
if (x_27 == 0)
{
return x_15;
}
else
{
lean_object* x_28; lean_object* x_29; lean_object* x_30; 
x_28 = lean_ctor_get(x_16, 0);
x_29 = lean_ctor_get(x_16, 1);
lean_inc(x_29);
lean_inc(x_28);
lean_dec(x_16);
x_30 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set(x_30, 1, x_29);
lean_ctor_set(x_15, 0, x_30);
return x_15;
}
}
else
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_31 = lean_ctor_get(x_15, 1);
lean_inc(x_31);
lean_dec(x_15);
x_32 = lean_ctor_get(x_16, 0);
lean_inc(x_32);
x_33 = lean_ctor_get(x_16, 1);
lean_inc(x_33);
if (lean_is_exclusive(x_16)) {
 lean_ctor_release(x_16, 0);
 lean_ctor_release(x_16, 1);
 x_34 = x_16;
} else {
 lean_dec_ref(x_16);
 x_34 = lean_box(0);
}
if (lean_is_scalar(x_34)) {
 x_35 = lean_alloc_ctor(1, 2, 0);
} else {
 x_35 = x_34;
}
lean_ctor_set(x_35, 0, x_32);
lean_ctor_set(x_35, 1, x_33);
x_36 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_36, 0, x_35);
lean_ctor_set(x_36, 1, x_31);
return x_36;
}
}
}
}
static lean_object* _init_l_Lake_GitRepo_branchExists___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("show-ref", 8, 8);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_branchExists___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("refs/heads/", 11, 11);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_branchExists___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_branchExists___closed__0;
x_2 = l_Lake_GitRepo_clone___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_branchExists___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_resolveRevision_x3f___closed__0;
x_2 = l_Lake_GitRepo_branchExists___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_branchExists(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_4 = l_Lake_GitRepo_branchExists___closed__1;
x_5 = lean_string_append(x_4, x_1);
x_6 = l_Lake_GitRepo_branchExists___closed__3;
x_7 = lean_array_push(x_6, x_5);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_9 = l_Lake_Git_filterUrl_x3f___closed__0;
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_2);
x_11 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_12 = 1;
x_13 = 0;
x_14 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_14, 0, x_8);
lean_ctor_set(x_14, 1, x_9);
lean_ctor_set(x_14, 2, x_7);
lean_ctor_set(x_14, 3, x_10);
lean_ctor_set(x_14, 4, x_11);
lean_ctor_set_uint8(x_14, sizeof(void*)*5, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*5 + 1, x_13);
x_15 = l_Lake_testProc(x_14, x_3);
return x_15;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_branchExists___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = l_Lake_GitRepo_branchExists(x_1, x_2, x_3);
lean_dec_ref(x_1);
return x_4;
}
}
static lean_object* _init_l_Lake_GitRepo_revisionExists___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("^{commit}", 9, 9);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_revisionExists___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_insideWorkTree___closed__0;
x_2 = l_Lake_GitRepo_clone___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_revisionExists___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_resolveRevision_x3f___closed__0;
x_2 = l_Lake_GitRepo_revisionExists___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_revisionExists(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_4 = l_Lake_GitRepo_revisionExists___closed__0;
x_5 = lean_string_append(x_1, x_4);
x_6 = l_Lake_GitRepo_revisionExists___closed__2;
x_7 = lean_array_push(x_6, x_5);
x_8 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_9 = l_Lake_Git_filterUrl_x3f___closed__0;
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_2);
x_11 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_12 = 1;
x_13 = 0;
x_14 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_14, 0, x_8);
lean_ctor_set(x_14, 1, x_9);
lean_ctor_set(x_14, 2, x_7);
lean_ctor_set(x_14, 3, x_10);
lean_ctor_set(x_14, 4, x_11);
lean_ctor_set_uint8(x_14, sizeof(void*)*5, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*5 + 1, x_13);
x_15 = l_Lake_testProc(x_14, x_3);
return x_15;
}
}
LEAN_EXPORT uint8_t l_Lake_GitRepo_getTags___lam__0(uint32_t x_1) {
_start:
{
uint32_t x_2; uint8_t x_3; 
x_2 = 10;
x_3 = lean_uint32_dec_eq(x_1, x_2);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_getTags___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("tag", 3, 3);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_getTags___closed__1() {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(1u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
static lean_object* _init_l_Lake_GitRepo_getTags___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_getTags___closed__0;
x_2 = l_Lake_GitRepo_getTags___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getTags(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; 
x_3 = l_Lake_GitRepo_getTags___closed__2;
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_3);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_captureProc_x3f(x_10, x_2);
x_12 = lean_ctor_get(x_11, 0);
lean_inc(x_12);
if (lean_obj_tag(x_12) == 0)
{
uint8_t x_13; 
x_13 = !lean_is_exclusive(x_11);
if (x_13 == 0)
{
lean_object* x_14; lean_object* x_15; 
x_14 = lean_ctor_get(x_11, 0);
lean_dec(x_14);
x_15 = lean_box(0);
lean_ctor_set(x_11, 0, x_15);
return x_11;
}
else
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_16 = lean_ctor_get(x_11, 1);
lean_inc(x_16);
lean_dec(x_11);
x_17 = lean_box(0);
x_18 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_18, 0, x_17);
lean_ctor_set(x_18, 1, x_16);
return x_18;
}
}
else
{
uint8_t x_19; 
x_19 = !lean_is_exclusive(x_11);
if (x_19 == 0)
{
lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; 
x_20 = lean_ctor_get(x_11, 0);
lean_dec(x_20);
x_21 = lean_ctor_get(x_12, 0);
lean_inc(x_21);
lean_dec_ref(x_12);
x_22 = lean_alloc_closure((void*)(l_Lake_GitRepo_getTags___lam__0___boxed), 1, 0);
x_23 = l_String_split(x_21, x_22);
lean_dec(x_21);
lean_ctor_set(x_11, 0, x_23);
return x_11;
}
else
{
lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; 
x_24 = lean_ctor_get(x_11, 1);
lean_inc(x_24);
lean_dec(x_11);
x_25 = lean_ctor_get(x_12, 0);
lean_inc(x_25);
lean_dec_ref(x_12);
x_26 = lean_alloc_closure((void*)(l_Lake_GitRepo_getTags___lam__0___boxed), 1, 0);
x_27 = l_String_split(x_25, x_26);
lean_dec(x_25);
x_28 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_24);
return x_28;
}
}
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getTags___lam__0___boxed(lean_object* x_1) {
_start:
{
uint32_t x_2; uint8_t x_3; lean_object* x_4; 
x_2 = lean_unbox_uint32(x_1);
lean_dec(x_1);
x_3 = l_Lake_GitRepo_getTags___lam__0(x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
static lean_object* _init_l_Lake_GitRepo_findTag_x3f___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("describe", 8, 8);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_findTag_x3f___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--exact-match", 13, 13);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_findTag_x3f___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_findTag_x3f___closed__0;
x_2 = l_Lake_GitRepo_fetch___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_findTag_x3f___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_fetch___closed__1;
x_2 = l_Lake_GitRepo_findTag_x3f___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_findTag_x3f___closed__4() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_findTag_x3f___closed__1;
x_2 = l_Lake_GitRepo_findTag_x3f___closed__3;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_findTag_x3f(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; 
x_4 = l_Lake_GitRepo_findTag_x3f___closed__4;
x_5 = lean_array_push(x_4, x_1);
x_6 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_7 = l_Lake_Git_filterUrl_x3f___closed__0;
x_8 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_8, 0, x_2);
x_9 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_10 = 1;
x_11 = 0;
x_12 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_12, 0, x_6);
lean_ctor_set(x_12, 1, x_7);
lean_ctor_set(x_12, 2, x_5);
lean_ctor_set(x_12, 3, x_8);
lean_ctor_set(x_12, 4, x_9);
lean_ctor_set_uint8(x_12, sizeof(void*)*5, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*5 + 1, x_11);
x_13 = l_Lake_captureProc_x3f(x_12, x_3);
return x_13;
}
}
static lean_object* _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("remote", 6, 6);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("get-url", 7, 7);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_getRemoteUrl_x3f___closed__0;
x_2 = l_Lake_GitRepo_clone___closed__1;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_getRemoteUrl_x3f___closed__1;
x_2 = l_Lake_GitRepo_getRemoteUrl_x3f___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getRemoteUrl_x3f(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; 
x_4 = l_Lake_GitRepo_getRemoteUrl_x3f___closed__3;
x_5 = lean_array_push(x_4, x_1);
x_6 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_7 = l_Lake_Git_filterUrl_x3f___closed__0;
x_8 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_8, 0, x_2);
x_9 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_10 = 1;
x_11 = 0;
x_12 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_12, 0, x_6);
lean_ctor_set(x_12, 1, x_7);
lean_ctor_set(x_12, 2, x_5);
lean_ctor_set(x_12, 3, x_8);
lean_ctor_set(x_12, 4, x_9);
lean_ctor_set_uint8(x_12, sizeof(void*)*5, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*5 + 1, x_11);
x_13 = l_Lake_captureProc_x3f(x_12, x_3);
return x_13;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_getFilteredRemoteUrl_x3f(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_4 = l_Lake_GitRepo_getRemoteUrl_x3f___closed__3;
x_5 = lean_array_push(x_4, x_1);
x_6 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_7 = l_Lake_Git_filterUrl_x3f___closed__0;
x_8 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_8, 0, x_2);
x_9 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_10 = 1;
x_11 = 0;
x_12 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_12, 0, x_6);
lean_ctor_set(x_12, 1, x_7);
lean_ctor_set(x_12, 2, x_5);
lean_ctor_set(x_12, 3, x_8);
lean_ctor_set(x_12, 4, x_9);
lean_ctor_set_uint8(x_12, sizeof(void*)*5, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*5 + 1, x_11);
x_13 = l_Lake_captureProc_x3f(x_12, x_3);
x_14 = lean_ctor_get(x_13, 0);
lean_inc(x_14);
if (lean_obj_tag(x_14) == 0)
{
return x_13;
}
else
{
uint8_t x_15; 
x_15 = !lean_is_exclusive(x_13);
if (x_15 == 0)
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_16 = lean_ctor_get(x_13, 0);
lean_dec(x_16);
x_17 = lean_ctor_get(x_14, 0);
lean_inc(x_17);
lean_dec_ref(x_14);
x_18 = l_Lake_Git_filterUrl_x3f(x_17);
lean_ctor_set(x_13, 0, x_18);
return x_13;
}
else
{
lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; 
x_19 = lean_ctor_get(x_13, 1);
lean_inc(x_19);
lean_dec(x_13);
x_20 = lean_ctor_get(x_14, 0);
lean_inc(x_20);
lean_dec_ref(x_14);
x_21 = l_Lake_Git_filterUrl_x3f(x_20);
x_22 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_22, 0, x_21);
lean_ctor_set(x_22, 1, x_19);
return x_22;
}
}
}
}
static lean_object* _init_l_Lake_GitRepo_hasNoDiff___closed__0() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("diff", 4, 4);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_hasNoDiff___closed__1() {
_start:
{
lean_object* x_1; 
x_1 = lean_mk_string_unchecked("--exit-code", 11, 11);
return x_1;
}
}
static lean_object* _init_l_Lake_GitRepo_hasNoDiff___closed__2() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_hasNoDiff___closed__0;
x_2 = l_Lake_GitRepo_quietInit___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
static lean_object* _init_l_Lake_GitRepo_hasNoDiff___closed__3() {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = l_Lake_GitRepo_hasNoDiff___closed__1;
x_2 = l_Lake_GitRepo_hasNoDiff___closed__2;
x_3 = lean_array_push(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_hasNoDiff(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_3 = l_Lake_GitRepo_hasNoDiff___closed__3;
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_3);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_testProc(x_10, x_2);
return x_11;
}
}
LEAN_EXPORT lean_object* l_Lake_GitRepo_hasDiff(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; 
x_3 = l_Lake_GitRepo_hasNoDiff___closed__3;
x_4 = l_Lake_GitRepo_captureGit_x3f___closed__0;
x_5 = l_Lake_Git_filterUrl_x3f___closed__0;
x_6 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_6, 0, x_1);
x_7 = l_Lake_GitRepo_captureGit_x3f___closed__1;
x_8 = 1;
x_9 = 0;
x_10 = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_5);
lean_ctor_set(x_10, 2, x_3);
lean_ctor_set(x_10, 3, x_6);
lean_ctor_set(x_10, 4, x_7);
lean_ctor_set_uint8(x_10, sizeof(void*)*5, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*5 + 1, x_9);
x_11 = l_Lake_testProc(x_10, x_2);
x_12 = lean_ctor_get(x_11, 0);
lean_inc(x_12);
x_13 = lean_unbox(x_12);
lean_dec(x_12);
if (x_13 == 0)
{
uint8_t x_14; 
x_14 = !lean_is_exclusive(x_11);
if (x_14 == 0)
{
lean_object* x_15; lean_object* x_16; 
x_15 = lean_ctor_get(x_11, 0);
lean_dec(x_15);
x_16 = lean_box(x_8);
lean_ctor_set(x_11, 0, x_16);
return x_11;
}
else
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; 
x_17 = lean_ctor_get(x_11, 1);
lean_inc(x_17);
lean_dec(x_11);
x_18 = lean_box(x_8);
x_19 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_19, 0, x_18);
lean_ctor_set(x_19, 1, x_17);
return x_19;
}
}
else
{
uint8_t x_20; 
x_20 = !lean_is_exclusive(x_11);
if (x_20 == 0)
{
lean_object* x_21; lean_object* x_22; 
x_21 = lean_ctor_get(x_11, 0);
lean_dec(x_21);
x_22 = lean_box(x_9);
lean_ctor_set(x_11, 0, x_22);
return x_11;
}
else
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; 
x_23 = lean_ctor_get(x_11, 1);
lean_inc(x_23);
lean_dec(x_11);
x_24 = lean_box(x_9);
x_25 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_25, 0, x_24);
lean_ctor_set(x_25, 1, x_23);
return x_25;
}
}
}
}
lean_object* initialize_Lake_Util_Proc(uint8_t builtin, lean_object*);
lean_object* initialize_Lake_Util_Lift(uint8_t builtin, lean_object*);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_Lake_Util_Git(uint8_t builtin, lean_object* w) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Lake_Util_Proc(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Lake_Util_Lift(builtin, lean_io_mk_world());
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
l_Lake_Git_defaultRemote___closed__0 = _init_l_Lake_Git_defaultRemote___closed__0();
lean_mark_persistent(l_Lake_Git_defaultRemote___closed__0);
l_Lake_Git_defaultRemote = _init_l_Lake_Git_defaultRemote();
lean_mark_persistent(l_Lake_Git_defaultRemote);
l_Lake_Git_upstreamBranch___closed__0 = _init_l_Lake_Git_upstreamBranch___closed__0();
lean_mark_persistent(l_Lake_Git_upstreamBranch___closed__0);
l_Lake_Git_upstreamBranch = _init_l_Lake_Git_upstreamBranch();
lean_mark_persistent(l_Lake_Git_upstreamBranch);
l_Lake_Git_filterUrl_x3f___closed__0 = _init_l_Lake_Git_filterUrl_x3f___closed__0();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__0);
l_Lake_Git_filterUrl_x3f___closed__1 = _init_l_Lake_Git_filterUrl_x3f___closed__1();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__1);
l_Lake_Git_filterUrl_x3f___closed__2 = _init_l_Lake_Git_filterUrl_x3f___closed__2();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__2);
l_Lake_Git_filterUrl_x3f___closed__3 = _init_l_Lake_Git_filterUrl_x3f___closed__3();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__3);
l_Lake_Git_filterUrl_x3f___closed__4 = _init_l_Lake_Git_filterUrl_x3f___closed__4();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__4);
l_Lake_Git_filterUrl_x3f___closed__5 = _init_l_Lake_Git_filterUrl_x3f___closed__5();
lean_mark_persistent(l_Lake_Git_filterUrl_x3f___closed__5);
l_Lake_instCoeFilePathGitRepo = _init_l_Lake_instCoeFilePathGitRepo();
lean_mark_persistent(l_Lake_instCoeFilePathGitRepo);
l_Lake_instToStringGitRepo___closed__0 = _init_l_Lake_instToStringGitRepo___closed__0();
lean_mark_persistent(l_Lake_instToStringGitRepo___closed__0);
l_Lake_instToStringGitRepo = _init_l_Lake_instToStringGitRepo();
lean_mark_persistent(l_Lake_instToStringGitRepo);
l_Lake_GitRepo_cwd___closed__0 = _init_l_Lake_GitRepo_cwd___closed__0();
lean_mark_persistent(l_Lake_GitRepo_cwd___closed__0);
l_Lake_GitRepo_cwd = _init_l_Lake_GitRepo_cwd();
lean_mark_persistent(l_Lake_GitRepo_cwd);
l_Lake_GitRepo_captureGit_x3f___closed__0 = _init_l_Lake_GitRepo_captureGit_x3f___closed__0();
lean_mark_persistent(l_Lake_GitRepo_captureGit_x3f___closed__0);
l_Lake_GitRepo_captureGit_x3f___closed__1 = _init_l_Lake_GitRepo_captureGit_x3f___closed__1();
lean_mark_persistent(l_Lake_GitRepo_captureGit_x3f___closed__1);
l_Lake_GitRepo_clone___closed__0 = _init_l_Lake_GitRepo_clone___closed__0();
lean_mark_persistent(l_Lake_GitRepo_clone___closed__0);
l_Lake_GitRepo_clone___closed__1 = _init_l_Lake_GitRepo_clone___closed__1();
lean_mark_persistent(l_Lake_GitRepo_clone___closed__1);
l_Lake_GitRepo_clone___closed__2 = _init_l_Lake_GitRepo_clone___closed__2();
lean_mark_persistent(l_Lake_GitRepo_clone___closed__2);
l_Lake_GitRepo_quietInit___closed__0 = _init_l_Lake_GitRepo_quietInit___closed__0();
lean_mark_persistent(l_Lake_GitRepo_quietInit___closed__0);
l_Lake_GitRepo_quietInit___closed__1 = _init_l_Lake_GitRepo_quietInit___closed__1();
lean_mark_persistent(l_Lake_GitRepo_quietInit___closed__1);
l_Lake_GitRepo_quietInit___closed__2 = _init_l_Lake_GitRepo_quietInit___closed__2();
lean_mark_persistent(l_Lake_GitRepo_quietInit___closed__2);
l_Lake_GitRepo_quietInit___closed__3 = _init_l_Lake_GitRepo_quietInit___closed__3();
lean_mark_persistent(l_Lake_GitRepo_quietInit___closed__3);
l_Lake_GitRepo_quietInit___closed__4 = _init_l_Lake_GitRepo_quietInit___closed__4();
lean_mark_persistent(l_Lake_GitRepo_quietInit___closed__4);
l_Lake_GitRepo_insideWorkTree___closed__0 = _init_l_Lake_GitRepo_insideWorkTree___closed__0();
lean_mark_persistent(l_Lake_GitRepo_insideWorkTree___closed__0);
l_Lake_GitRepo_insideWorkTree___closed__1 = _init_l_Lake_GitRepo_insideWorkTree___closed__1();
lean_mark_persistent(l_Lake_GitRepo_insideWorkTree___closed__1);
l_Lake_GitRepo_insideWorkTree___closed__2 = _init_l_Lake_GitRepo_insideWorkTree___closed__2();
lean_mark_persistent(l_Lake_GitRepo_insideWorkTree___closed__2);
l_Lake_GitRepo_insideWorkTree___closed__3 = _init_l_Lake_GitRepo_insideWorkTree___closed__3();
lean_mark_persistent(l_Lake_GitRepo_insideWorkTree___closed__3);
l_Lake_GitRepo_fetch___closed__0 = _init_l_Lake_GitRepo_fetch___closed__0();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__0);
l_Lake_GitRepo_fetch___closed__1 = _init_l_Lake_GitRepo_fetch___closed__1();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__1);
l_Lake_GitRepo_fetch___closed__2 = _init_l_Lake_GitRepo_fetch___closed__2();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__2);
l_Lake_GitRepo_fetch___closed__3 = _init_l_Lake_GitRepo_fetch___closed__3();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__3);
l_Lake_GitRepo_fetch___closed__4 = _init_l_Lake_GitRepo_fetch___closed__4();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__4);
l_Lake_GitRepo_fetch___closed__5 = _init_l_Lake_GitRepo_fetch___closed__5();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__5);
l_Lake_GitRepo_fetch___closed__6 = _init_l_Lake_GitRepo_fetch___closed__6();
lean_mark_persistent(l_Lake_GitRepo_fetch___closed__6);
l_Lake_GitRepo_checkoutBranch___closed__0 = _init_l_Lake_GitRepo_checkoutBranch___closed__0();
lean_mark_persistent(l_Lake_GitRepo_checkoutBranch___closed__0);
l_Lake_GitRepo_checkoutBranch___closed__1 = _init_l_Lake_GitRepo_checkoutBranch___closed__1();
lean_mark_persistent(l_Lake_GitRepo_checkoutBranch___closed__1);
l_Lake_GitRepo_checkoutBranch___closed__2 = _init_l_Lake_GitRepo_checkoutBranch___closed__2();
lean_mark_persistent(l_Lake_GitRepo_checkoutBranch___closed__2);
l_Lake_GitRepo_checkoutBranch___closed__3 = _init_l_Lake_GitRepo_checkoutBranch___closed__3();
lean_mark_persistent(l_Lake_GitRepo_checkoutBranch___closed__3);
l_Lake_GitRepo_checkoutDetach___closed__0 = _init_l_Lake_GitRepo_checkoutDetach___closed__0();
lean_mark_persistent(l_Lake_GitRepo_checkoutDetach___closed__0);
l_Lake_GitRepo_checkoutDetach___closed__1 = _init_l_Lake_GitRepo_checkoutDetach___closed__1();
lean_mark_persistent(l_Lake_GitRepo_checkoutDetach___closed__1);
l_Lake_GitRepo_checkoutDetach___closed__2 = _init_l_Lake_GitRepo_checkoutDetach___closed__2();
lean_mark_persistent(l_Lake_GitRepo_checkoutDetach___closed__2);
l_Lake_GitRepo_checkoutDetach___closed__3 = _init_l_Lake_GitRepo_checkoutDetach___closed__3();
lean_mark_persistent(l_Lake_GitRepo_checkoutDetach___closed__3);
l_Lake_GitRepo_resolveRevision_x3f___closed__0 = _init_l_Lake_GitRepo_resolveRevision_x3f___closed__0();
lean_mark_persistent(l_Lake_GitRepo_resolveRevision_x3f___closed__0);
l_Lake_GitRepo_resolveRevision_x3f___closed__1 = _init_l_Lake_GitRepo_resolveRevision_x3f___closed__1();
lean_mark_persistent(l_Lake_GitRepo_resolveRevision_x3f___closed__1);
l_Lake_GitRepo_resolveRevision_x3f___closed__2 = _init_l_Lake_GitRepo_resolveRevision_x3f___closed__2();
lean_mark_persistent(l_Lake_GitRepo_resolveRevision_x3f___closed__2);
l_Lake_GitRepo_resolveRevision_x3f___closed__3 = _init_l_Lake_GitRepo_resolveRevision_x3f___closed__3();
lean_mark_persistent(l_Lake_GitRepo_resolveRevision_x3f___closed__3);
l_Lake_GitRepo_resolveRevision_x3f___closed__4 = _init_l_Lake_GitRepo_resolveRevision_x3f___closed__4();
lean_mark_persistent(l_Lake_GitRepo_resolveRevision_x3f___closed__4);
l_Lake_GitRepo_getHeadRevision_x3f___closed__0 = _init_l_Lake_GitRepo_getHeadRevision_x3f___closed__0();
lean_mark_persistent(l_Lake_GitRepo_getHeadRevision_x3f___closed__0);
l_Lake_GitRepo_getHeadRevision_x3f___closed__1 = _init_l_Lake_GitRepo_getHeadRevision_x3f___closed__1();
lean_mark_persistent(l_Lake_GitRepo_getHeadRevision_x3f___closed__1);
l_Lake_GitRepo_getHeadRevision___closed__0 = _init_l_Lake_GitRepo_getHeadRevision___closed__0();
lean_mark_persistent(l_Lake_GitRepo_getHeadRevision___closed__0);
l_Lake_GitRepo_resolveRemoteRevision___closed__0 = _init_l_Lake_GitRepo_resolveRemoteRevision___closed__0();
lean_mark_persistent(l_Lake_GitRepo_resolveRemoteRevision___closed__0);
l_Lake_GitRepo_resolveRemoteRevision___closed__1 = _init_l_Lake_GitRepo_resolveRemoteRevision___closed__1();
lean_mark_persistent(l_Lake_GitRepo_resolveRemoteRevision___closed__1);
l_Lake_GitRepo_resolveRemoteRevision___closed__2 = _init_l_Lake_GitRepo_resolveRemoteRevision___closed__2();
lean_mark_persistent(l_Lake_GitRepo_resolveRemoteRevision___closed__2);
l_Lake_GitRepo_branchExists___closed__0 = _init_l_Lake_GitRepo_branchExists___closed__0();
lean_mark_persistent(l_Lake_GitRepo_branchExists___closed__0);
l_Lake_GitRepo_branchExists___closed__1 = _init_l_Lake_GitRepo_branchExists___closed__1();
lean_mark_persistent(l_Lake_GitRepo_branchExists___closed__1);
l_Lake_GitRepo_branchExists___closed__2 = _init_l_Lake_GitRepo_branchExists___closed__2();
lean_mark_persistent(l_Lake_GitRepo_branchExists___closed__2);
l_Lake_GitRepo_branchExists___closed__3 = _init_l_Lake_GitRepo_branchExists___closed__3();
lean_mark_persistent(l_Lake_GitRepo_branchExists___closed__3);
l_Lake_GitRepo_revisionExists___closed__0 = _init_l_Lake_GitRepo_revisionExists___closed__0();
lean_mark_persistent(l_Lake_GitRepo_revisionExists___closed__0);
l_Lake_GitRepo_revisionExists___closed__1 = _init_l_Lake_GitRepo_revisionExists___closed__1();
lean_mark_persistent(l_Lake_GitRepo_revisionExists___closed__1);
l_Lake_GitRepo_revisionExists___closed__2 = _init_l_Lake_GitRepo_revisionExists___closed__2();
lean_mark_persistent(l_Lake_GitRepo_revisionExists___closed__2);
l_Lake_GitRepo_getTags___closed__0 = _init_l_Lake_GitRepo_getTags___closed__0();
lean_mark_persistent(l_Lake_GitRepo_getTags___closed__0);
l_Lake_GitRepo_getTags___closed__1 = _init_l_Lake_GitRepo_getTags___closed__1();
lean_mark_persistent(l_Lake_GitRepo_getTags___closed__1);
l_Lake_GitRepo_getTags___closed__2 = _init_l_Lake_GitRepo_getTags___closed__2();
lean_mark_persistent(l_Lake_GitRepo_getTags___closed__2);
l_Lake_GitRepo_findTag_x3f___closed__0 = _init_l_Lake_GitRepo_findTag_x3f___closed__0();
lean_mark_persistent(l_Lake_GitRepo_findTag_x3f___closed__0);
l_Lake_GitRepo_findTag_x3f___closed__1 = _init_l_Lake_GitRepo_findTag_x3f___closed__1();
lean_mark_persistent(l_Lake_GitRepo_findTag_x3f___closed__1);
l_Lake_GitRepo_findTag_x3f___closed__2 = _init_l_Lake_GitRepo_findTag_x3f___closed__2();
lean_mark_persistent(l_Lake_GitRepo_findTag_x3f___closed__2);
l_Lake_GitRepo_findTag_x3f___closed__3 = _init_l_Lake_GitRepo_findTag_x3f___closed__3();
lean_mark_persistent(l_Lake_GitRepo_findTag_x3f___closed__3);
l_Lake_GitRepo_findTag_x3f___closed__4 = _init_l_Lake_GitRepo_findTag_x3f___closed__4();
lean_mark_persistent(l_Lake_GitRepo_findTag_x3f___closed__4);
l_Lake_GitRepo_getRemoteUrl_x3f___closed__0 = _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__0();
lean_mark_persistent(l_Lake_GitRepo_getRemoteUrl_x3f___closed__0);
l_Lake_GitRepo_getRemoteUrl_x3f___closed__1 = _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__1();
lean_mark_persistent(l_Lake_GitRepo_getRemoteUrl_x3f___closed__1);
l_Lake_GitRepo_getRemoteUrl_x3f___closed__2 = _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__2();
lean_mark_persistent(l_Lake_GitRepo_getRemoteUrl_x3f___closed__2);
l_Lake_GitRepo_getRemoteUrl_x3f___closed__3 = _init_l_Lake_GitRepo_getRemoteUrl_x3f___closed__3();
lean_mark_persistent(l_Lake_GitRepo_getRemoteUrl_x3f___closed__3);
l_Lake_GitRepo_hasNoDiff___closed__0 = _init_l_Lake_GitRepo_hasNoDiff___closed__0();
lean_mark_persistent(l_Lake_GitRepo_hasNoDiff___closed__0);
l_Lake_GitRepo_hasNoDiff___closed__1 = _init_l_Lake_GitRepo_hasNoDiff___closed__1();
lean_mark_persistent(l_Lake_GitRepo_hasNoDiff___closed__1);
l_Lake_GitRepo_hasNoDiff___closed__2 = _init_l_Lake_GitRepo_hasNoDiff___closed__2();
lean_mark_persistent(l_Lake_GitRepo_hasNoDiff___closed__2);
l_Lake_GitRepo_hasNoDiff___closed__3 = _init_l_Lake_GitRepo_hasNoDiff___closed__3();
lean_mark_persistent(l_Lake_GitRepo_hasNoDiff___closed__3);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
