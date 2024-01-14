#include "mips32.h"

/* the output file descriptor, may not be explicitly used */
FILE *fd;
VarDesc *vars_tail;
int offset = 1;
Register cur_reg = t0;
State *state;
State *state_tail;

#define _tac_kind(tac) (((tac)->code).kind)
#define _tac_quadruple(tac) (((tac)->code).tac)
#define _reg_name(reg) regs[reg].name
#define _reg_var(reg) regs[reg].var
#define _reg_dirty(reg) regs[reg].dirty
#define _reg_live(reg) regs[reg].live
#define max(a,b) (a > b ? a : b)

void save_state() {
    
    state = (State*)malloc(sizeof(State));
    state->regs = (RegDesc*)malloc(sizeof(RegDesc) * NUM_REGS);
    state->vars = NULL;
    state->offset = offset;
    state->cur_reg = cur_reg;
    memcpy(state->regs, regs, sizeof(RegDesc) * NUM_REGS);
    VarDesc *curr_var = vars;
    VarDesc *new_var = NULL;
    VarDesc **last_ptr = &state->vars;
    while (curr_var != NULL) {
        new_var = malloc(sizeof(VarDesc));
        memcpy(new_var, curr_var, sizeof(VarDesc));
        *last_ptr = new_var;    
        last_ptr = &(new_var->next);
        curr_var = curr_var->next;
    }
    state->vars_tail = new_var;
}

void load_state() {
    VarDesc *curr_var = vars;
    VarDesc *next_var = NULL;

    while (curr_var != NULL) {
        next_var = curr_var->next;
        free(curr_var);
        curr_var = next_var;
    }

    vars = state->vars;
    memcpy(regs, state->regs, sizeof(RegDesc) * NUM_REGS);
    free(state->regs);
    vars_tail = state->vars_tail;
    offset = state->offset;
    cur_reg = state->cur_reg;
    state = NULL;
}

void clear_reg(Register reg){
    strcpy(_reg_var(reg), "");
    _reg_live(reg) = FALSE;
    _reg_dirty(reg) = FALSE;
}

void clear_regs(){
    for (Register reg = a0; reg <= s7; reg++) {
        clear_reg(reg);
    }
}

char* get_output_path(const char* file) {
    const char* extension = ".s";
    char* output_path = (char*) malloc(strlen(file) + strlen(extension) + 1);
    strcpy(output_path, file);
    char* ir_extension = strstr(output_path, ".ir");
    if (ir_extension != NULL) {
        strncpy(ir_extension, extension, strlen(extension));
    }
    
    return output_path;
}

void _mips_printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(fd, fmt, args);
    va_end(args);
    fputs("\n", fd);
}

void _mips_iprintf(const char *fmt, ...) {
    va_list args;
    fputs("  ", fd); // `iprintf` stands for indented // // printf
    va_start(args, fmt);
    vfprintf(fd, fmt, args);
    va_end(args);
    fputs("\n", fd);
}

VarDesc* get_var(char* var) {
    VarDesc* cur = vars;
    while (cur != NULL && strcmp(cur->var, var) != 0) {
        cur = cur->next;
    }
    return cur;
}

VarDesc* new_var(char* var, int offset) {
    vars_tail->next = (VarDesc*)malloc(sizeof(VarDesc));
    vars_tail = vars_tail->next;
    strcpy(vars_tail->var, var);
    vars_tail->offset = offset;
    vars_tail->next = NULL;
    return vars_tail;
}

void load_register_mem(Register reg, VarDesc* varDesc) {
    _mips_iprintf("lw %s %d($sp)", _reg_name(reg), -varDesc->offset * 4);
    strcpy(_reg_var(reg), varDesc->var);
    _reg_live(reg) = TRUE;
    _reg_dirty(reg) = FALSE;
    varDesc->reg = reg;
}

void load_register(Register reg, VarDesc* varDesc) {
    strcpy(_reg_var(reg), varDesc->var);
    _reg_live(reg) = TRUE;
    _reg_dirty(reg) = TRUE;
    varDesc->reg = reg;
}

void spill_register(Register reg) {
    /* COMPLETE the register spilling */
    if (!_reg_live(reg) || !_reg_dirty(reg)) {
        return;
    }
    VarDesc* var = get_var(_reg_var(reg));
    _reg_dirty(reg) = FALSE;
    _mips_iprintf("sw %s, %d($sp)", _reg_name(reg), -var->offset * 4);
}

Register find_empty_register() {
    // 有寄存器为空
    for(Register reg = t0; reg < s7; reg++) {
        if (!_reg_live(reg)) {
            return reg;
            break;
        }
    }

    // 有寄存器与内存一致
    for (Register reg = t0; reg < s7; reg++) {
        if (!_reg_dirty(reg)) {
            return reg;
        }
    }

    // 没有寄存器与内存一致，将一个寄存器写入内存
    Register target = ((cur_reg++) - t0) % 16 + t0;
    spill_register(target);
    return target;
}

Register get_register(tac_opd *opd) {
    assert(opd->kind == OP_VARIABLE);
    char *var = opd->char_val;
    /* COMPLETE the register allocation */
    // 遍历vars寻找var
    VarDesc* varDesc = get_var(var);
    // 读变量，一定能找到，且不是第一次出现
    assert(varDesc != NULL);

    // 在寄存器中
    if (varDesc->reg != zero){
        return varDesc->reg;
    }
    
    // 在内存中，将变量写到某个寄存器中
    Register reg = find_empty_register();
    load_register_mem(reg, varDesc);
    _reg_live(reg) = TRUE;
    _reg_dirty(reg) = TRUE;
    return reg;
}

Register get_register_w(tac_opd *opd) {
    assert(opd->kind == OP_VARIABLE);
    char *var = opd->char_val;
    /* COMPLETE the register allocation (for write) */
    // 遍历vars寻找var
    VarDesc* varDesc = get_var(var);
    
    // 在寄存器中
    if (varDesc != NULL && varDesc->reg != zero) {
        _reg_dirty(varDesc->reg) = TRUE;
        return varDesc->reg;
    }
    
    // 不在寄存器中，找一个空寄存器
    Register reg = find_empty_register();

    // 对于不在寄存器中的var, 有两种情况：
    // 1.是新的var
    if (varDesc == NULL) {
        varDesc = new_var(var, offset++);
        load_register(reg, varDesc);
    }
    
    // 2.已经在内存中
    if (varDesc->reg == zero) {
        load_register_mem(reg, varDesc);
    }
    _reg_live(reg) = TRUE;
    _reg_dirty(reg) = TRUE;
    return reg;
}


/* PARAM: a pointer to `struct tac_node` instance
   RETURN: the next instruction to be translated */
tac *emit_label(tac *label){
    assert(_tac_kind(label) == LABEL);
    if (state == NULL) {
        save_state();
    } else {
        load_state();
    }
    _mips_printf("label%d:", _tac_quadruple(label).labelno->int_val);
    return label->next;
}

tac *emit_function(tac *function){
    _mips_printf("%s:", _tac_quadruple(function).funcname);
    clear_regs();
    offset = 1;
    return function->next;
}

tac *emit_assign(tac *assign){
    Register x, y;
    x = get_register_w(_tac_quadruple(assign).left);
    if(_tac_quadruple(assign).right->kind == OP_CONSTANT){
        _mips_iprintf("li %s, %d", _reg_name(x),
                                   _tac_quadruple(assign).right->int_val);
    }
    else{
        y = get_register(_tac_quadruple(assign).right);
        _mips_iprintf("move %s, %s", _reg_name(x), _reg_name(y));
    }
    return assign->next;
}

tac *emit_add(tac *add){
    Register x, y, z;

    x = get_register_w(_tac_quadruple(add).left);
    if(_tac_quadruple(add).r1->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(add).r2);
        _mips_iprintf("addi %s, %s, %d", _reg_name(x),
                                         _reg_name(y),
                                         _tac_quadruple(add).r1->int_val);
    }
    else if(_tac_quadruple(add).r2->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(add).r1);
        _mips_iprintf("addi %s, %s, %d", _reg_name(x),
                                         _reg_name(y),
                                         _tac_quadruple(add).r2->int_val);
    }
    else{
        y = get_register(_tac_quadruple(add).r1);
        z = get_register(_tac_quadruple(add).r2);
        _mips_iprintf("add %s, %s, %s", _reg_name(x),
                                        _reg_name(y),
                                        _reg_name(z));
    }
    return add->next;
}

tac *emit_sub(tac *sub){
    Register x, y, z;
    x = get_register_w(_tac_quadruple(sub).left);
    if(_tac_quadruple(sub).r1->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(sub).r2);
        _mips_iprintf("neg %s, %s", _reg_name(y), _reg_name(y));
        _mips_iprintf("addi %s, %s, %d", _reg_name(x),
                                         _reg_name(y),
                                         _tac_quadruple(sub).r1->int_val);
    }
    else if(_tac_quadruple(sub).r2->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(sub).r1);
        _mips_iprintf("addi %s, %s, -%d", _reg_name(x),
                                          _reg_name(y),
                                          _tac_quadruple(sub).r2->int_val);
    }
    else{
        y = get_register(_tac_quadruple(sub).r1);
        z = get_register(_tac_quadruple(sub).r2);
        _mips_iprintf("sub %s, %s, %s", _reg_name(x),
                                        _reg_name(y),
                                        _reg_name(z));
    }
    return sub->next;
}

tac *emit_mul(tac *mul){
    Register x, y, z;

    x = get_register_w(_tac_quadruple(mul).left);
    if(_tac_quadruple(mul).r1->kind == OP_CONSTANT){
        y = get_register_w(_tac_quadruple(mul).r1);
        z = get_register(_tac_quadruple(mul).r2);
        _mips_iprintf("lw %s, %d", _reg_name(y),
                                   _tac_quadruple(mul).r1->int_val);
    }
    else if(_tac_quadruple(mul).r2->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(mul).r1);
        z = get_register_w(_tac_quadruple(mul).r2);
        _mips_iprintf("lw %s, %d", _reg_name(z),
                                   _tac_quadruple(mul).r2->int_val);
    }
    else{
        y = get_register(_tac_quadruple(mul).r1);
        z = get_register(_tac_quadruple(mul).r2);
    }
    _mips_iprintf("mul %s, %s, %s", _reg_name(x),
                                    _reg_name(y),
                                    _reg_name(z));
    return mul->next;
}

tac *emit_div(tac *div){
    Register x, y, z;

    x = get_register_w(_tac_quadruple(div).left);
    if(_tac_quadruple(div).r1->kind == OP_CONSTANT){
        y = get_register_w(_tac_quadruple(div).r1);
        z = get_register(_tac_quadruple(div).r2);
        _mips_iprintf("lw %s, %d", _reg_name(y),
                                   _tac_quadruple(div).r1->int_val);
    }
    else if(_tac_quadruple(div).r2->kind == OP_CONSTANT){
        y = get_register(_tac_quadruple(div).r1);
        z = get_register_w(_tac_quadruple(div).r2);
        _mips_iprintf("lw %s, %d", _reg_name(z),
                                   _tac_quadruple(div).r2->int_val);
    }
    else{
        y = get_register(_tac_quadruple(div).r1);
        z = get_register(_tac_quadruple(div).r2);
    }
    _mips_iprintf("div %s, %s", _reg_name(y), _reg_name(z));
    _mips_iprintf("mflo %s", _reg_name(x));
    return div->next;
}

tac *emit_addr(tac *addr){
    Register x, y;
    x = get_register_w(_tac_quadruple(addr).left);
    y = get_register(_tac_quadruple(addr).right);
    _mips_iprintf("move %s, %s", _reg_name(x), _reg_name(y));
    return addr->next;
}

tac *emit_fetch(tac *fetch){
    Register x, y;

    x = get_register_w(_tac_quadruple(fetch).left);
    y = get_register(_tac_quadruple(fetch).raddr);
    _mips_iprintf("lw %s, 0(%s)", _reg_name(x), _reg_name(y));
    return fetch->next;
}

tac *emit_deref(tac *deref){
    Register x, y;

    x = get_register(_tac_quadruple(deref).laddr);
    y = get_register(_tac_quadruple(deref).right);
    _mips_iprintf("sw %s, 0(%s)", _reg_name(y), _reg_name(x));
    return deref->next;
}

tac *emit_goto(tac *goto_){
    _mips_iprintf("j label%d", _tac_quadruple(goto_).labelno->int_val);
    return goto_->next;
}

tac *emit_iflt(tac *iflt){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(iflt).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(iflt).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(iflt).c2);
    }
    else if(_tac_quadruple(iflt).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(iflt).c2->int_val);
        x = get_register(_tac_quadruple(iflt).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(iflt).c1);
        y = get_register(_tac_quadruple(iflt).c2);
        
    }
    _mips_iprintf("blt %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(iflt).labelno->int_val);
    return iflt->next;
}

tac *emit_ifle(tac *ifle){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(ifle).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifle).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(ifle).c2);
    }
    else if(_tac_quadruple(ifle).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifle).c2->int_val);
        x = get_register(_tac_quadruple(ifle).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(ifle).c1);
        y = get_register(_tac_quadruple(ifle).c2);
        
    }
    _mips_iprintf("ble %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(ifle).labelno->int_val);
    return ifle->next;
}

tac *emit_ifgt(tac *ifgt){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(ifgt).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifgt).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(ifgt).c2);
    }
    else if(_tac_quadruple(ifgt).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifgt).c2->int_val);
        x = get_register(_tac_quadruple(ifgt).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(ifgt).c1);
        y = get_register(_tac_quadruple(ifgt).c2);
        
    }
    _mips_iprintf("bgt %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(ifgt).labelno->int_val);
    return ifgt->next;
}

tac *emit_ifge(tac *ifge){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(ifge).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifge).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(ifge).c2);
    }
    else if(_tac_quadruple(ifge).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifge).c2->int_val);
        x = get_register(_tac_quadruple(ifge).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(ifge).c1);
        y = get_register(_tac_quadruple(ifge).c2);
        
    }
    _mips_iprintf("bge %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(ifge).labelno->int_val);
    return ifge->next;
}

tac *emit_ifne(tac *ifne){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(ifne).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifne).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(ifne).c2);
    }
    else if(_tac_quadruple(ifne).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifne).c2->int_val);
        x = get_register(_tac_quadruple(ifne).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(ifne).c1);
        y = get_register(_tac_quadruple(ifne).c2);
        
    }
    _mips_iprintf("bne %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(ifne).labelno->int_val);
    return ifne->next;
}

tac *emit_ifeq(tac *ifeq){
    /* COMPLETE emit function */
    Register x, y;
    if(_tac_quadruple(ifeq).c1->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifeq).c1->int_val);
        x = v1;
        y = get_register(_tac_quadruple(ifeq).c2);
    }
    else if(_tac_quadruple(ifeq).c2->kind == OP_CONSTANT){
        _mips_iprintf("li $v1, %d", _tac_quadruple(ifeq).c2->int_val);
        x = get_register(_tac_quadruple(ifeq).c1);
        y = v1;
    }
    else{
        x = get_register(_tac_quadruple(ifeq).c1);
        y = get_register(_tac_quadruple(ifeq).c2);
        
    }
    _mips_iprintf("beq %s, %s, label%d",
                    _reg_name(x),
                    _reg_name(y),
                    _tac_quadruple(ifeq).labelno->int_val);
    return ifeq->next;
}

tac *emit_return(tac *return_){
    /* COMPLETE emit function */
    if (_tac_quadruple(return_).var->kind == OP_CONSTANT){
        _mips_iprintf("li $v0, %d", _tac_quadruple(return_).var->int_val);
    } else {
        VarDesc* var = get_var(_tac_quadruple(return_).var->char_val);
        if (var->reg != zero) {
            _mips_iprintf("move $v0, %s", _reg_name(var->reg));
        } else {
            _mips_iprintf("lw $v0, %d($sp)", -var->offset);
        }
    }
    _mips_iprintf("jr $ra");
    return return_->next;    
}

tac *emit_dec(tac *dec){
    /* NO NEED TO IMPLEMENT */
    return dec->next;
}

tac *emit_arg(tac *arg) {
    /* COMPLETE emit function */
    return arg->next;
}

void _emit_arg(tac *arg) {
    Register arg_cnt = a0;
    tac *call = arg;
    while (_tac_kind(call) != CALL) {
        call = call->next;
        arg_cnt++;
    }
    Register x;
    for(Register cnt = arg_cnt - 1; cnt >= a0; cnt--){
        if (cnt >= a0 && cnt <= a3) {
            spill_register(cnt);
            if (_tac_quadruple(arg).var->kind == OP_CONSTANT) {
                _mips_iprintf("li %s, %d", _reg_name(cnt), _tac_quadruple(arg).var->int_val);       
            } else {
                _mips_iprintf("move %s, %s", _reg_name(cnt), _reg_name(get_register(_tac_quadruple(arg).var)));
            }
        } else {
            if (_tac_quadruple(arg).var->kind == OP_CONSTANT) {    
                _mips_iprintf("li $v1, %d", _reg_name(cnt), _tac_quadruple(arg).var->int_val);
                _mips_iprintf("sw $v1, %d($sp)", -(offset++) * 4);
            } else {
                x = get_register(_tac_quadruple(arg).var);
                _mips_iprintf("sw %s, %d($sp)", _reg_name(x), -(offset++) * 4);
            }
        }
        arg = arg->next;
    }
}

tac *emit_call(tac *call){
    /* COMPLETE emit function */
    VarDesc* temp_vars[32];
    int flag = 0;
    for (Register reg = a0; reg <= s7; reg++) {
        if (_reg_live(reg) && _reg_dirty(reg)) {
            temp_vars[reg] = get_var(_reg_var(reg));
            spill_register(reg);
        } else {
            temp_vars[reg] = NULL;
        }
    }
    tac *arg = call;
    while (_tac_kind(arg->prev)==ARG) {
        arg = arg->prev;
    }

    if (_tac_kind(arg)==ARG) {
        _emit_arg(arg);
    }
    
    int call_offset = offset;
    _mips_iprintf("sw $ra, 0($sp)");
    _mips_iprintf("addi $sp, $sp, %d", -4 * call_offset);
    
    _mips_iprintf("jal %s", _tac_quadruple(call).funcname);
    
    _mips_iprintf("addi $sp, $sp, %d", 4 * call_offset);
    _mips_iprintf("lw $ra, 0($sp)");
    
    for (Register reg = s7; reg >= a0; reg--) {
        if (temp_vars[reg] != NULL){
            load_register_mem(reg, temp_vars[reg]);
        }
    }
    _mips_iprintf("move %s, $v0", _reg_name(get_register_w(_tac_quadruple(call).ret)));
    return call->next;
}

tac *emit_param(tac *param){
    /* COMPLETE emit function */
    int param_cnt = a0;
    while (_tac_kind(param) == PARAM){
        VarDesc *var;
        
        if (param_cnt <= a3){
            var = new_var(_tac_quadruple(param).p->char_val, offset++);
            load_register(param_cnt, var);
        } else{
            var = new_var(_tac_quadruple(param).p->char_val, a3 - param_cnt);
        }
        param_cnt++;
        param = param->next;
    }
    param_cnt = a0;
    return param;
}

tac *emit_read(tac *read){
    Register x = get_register_w(_tac_quadruple(read).p);

    _mips_iprintf("addi $sp, $sp, -4");
    _mips_iprintf("sw $ra, 0($sp)");
    _mips_iprintf("jal read");
    _mips_iprintf("lw $ra, 0($sp)");
    _mips_iprintf("addi $sp, $sp, 4");
    _mips_iprintf("move %s, $v0", _reg_name(x));
    return read->next;
}

tac *emit_write(tac *write){
    Register x = get_register_w(_tac_quadruple(write).p);
    if (_reg_live(a0) && _reg_dirty(a0)) {
        _mips_iprintf("sw $a0, %d($sp)", -4 * get_var(_reg_var(a0))->offset);
    }
    
    _mips_iprintf("move $a0, %s", _reg_name(x));
    
    _mips_iprintf("sw $ra, 0($sp)");
    _mips_iprintf("addi $sp, $sp, -4");
    _mips_iprintf("jal write");
    _mips_iprintf("addi $sp, $sp, 4");
    _mips_iprintf("lw $ra, 0($sp)");
    if (_reg_live(a0)) {
        _mips_iprintf("lw $a0, %d($sp)", -4 * get_var(_reg_var(a0))->offset);
    }
    
    return write->next;
}

void emit_preamble(){
    _mips_printf("# SPL compiler generated assembly");
    _mips_printf(".data");
    _mips_printf("_prmpt: .asciiz \"Enter an integer: \"");
    _mips_printf("_eol: .asciiz \"\\n\"");
    _mips_printf(".globl main");
    _mips_printf(".text");
}

void emit_read_function(){
    _mips_printf("read:");
    _mips_iprintf("li $v0, 4");
    _mips_iprintf("la $a0, _prmpt");
    _mips_iprintf("syscall");
    _mips_iprintf("li $v0, 5");
    _mips_iprintf("syscall");
    _mips_iprintf("jr $ra");
}

void emit_write_function(){
    _mips_printf("write:");
    _mips_iprintf("li $v0, 1");
    _mips_iprintf("syscall");
    _mips_iprintf("li $v0, 4");
    _mips_iprintf("la $a0, _eol");
    _mips_iprintf("syscall");
    _mips_iprintf("move $v0, $0");
    _mips_iprintf("jr $ra");
}

static tac* (*emitter[])(tac*) = {
    emit_label, emit_function, emit_assign,
    emit_add, emit_sub, emit_mul, emit_div,
    emit_addr, emit_fetch, emit_deref, emit_goto,
    emit_iflt, emit_ifle, emit_ifgt, emit_ifge, emit_ifne, emit_ifeq,
    emit_return, emit_dec, emit_arg, emit_call, emit_param,
    emit_read, emit_write
};

tac *emit_code(tac *head){
    tac *(*tac_emitter)(tac*);
    tac *tac_code = head;
    emit_preamble();
    emit_read_function();
    emit_write_function();
    while(tac_code != NULL){
        if(_tac_kind(tac_code) != NONE){
            tac_emitter = emitter[_tac_kind(tac_code)];
            tac_code = tac_emitter(tac_code);
        }
        else{
            tac_code = tac_code->next;
        }
    }
    return NULL;
}

/* translate a TAC list into mips32 assembly
   output the textual assembly code to _fd */
void mips32_gen(tac *head, FILE *_fd){
    regs[zero].name = "$zero";
    regs[at].name = "$at";
    regs[v0].name = "$v0"; regs[v1].name = "$v1";
    regs[a0].name = "$a0"; regs[a1].name = "$a1";
    regs[a2].name = "$a2"; regs[a3].name = "$a3";
    regs[t0].name = "$t0"; regs[t1].name = "$t1";
    regs[t2].name = "$t2"; regs[t3].name = "$t3";
    regs[t4].name = "$t4"; regs[t5].name = "$t5";
    regs[t6].name = "$t6"; regs[t7].name = "$t7";
    regs[s0].name = "$s0"; regs[s1].name = "$s1";
    regs[s2].name = "$s2"; regs[s3].name = "$s3";
    regs[s4].name = "$s4"; regs[s5].name = "$s5";
    regs[s6].name = "$s6"; regs[s7].name = "$s7";
    regs[t8].name = "$t8"; regs[t9].name = "$t9";
    regs[k0].name = "$k0"; regs[k1].name = "$k1";
    regs[gp].name = "$gp";
    regs[sp].name = "$sp"; regs[fp].name = "$fp";
    regs[ra].name = "$ra";
    vars = (VarDesc*)malloc(sizeof(VarDesc));
    vars->next = NULL;
    strcpy(vars->var, "df");
    vars_tail = vars;
    fd = _fd;
    emit_code(head);
}
