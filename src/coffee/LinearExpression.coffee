include Cl
include Cl.AbstractVariable as AbstractVariable

include Cl.HashTable as HashTable

class Cl.LinearExpression

  constructor: (clv, value, constant) ->
    @_constant = constant || 0
    @_terms = new HashTable()
    if clv instanceof AbstractVariable
      @_terms.put clv, value || 1
    else if typeof(clv) == "number"
      @_constant = clv

  initializeFromHash: (@_constant, terms) ->
    @_terms = terms.clone()
    return this

  clone: -> new Cl.LinearExpression().initializeFromHash @_constant, @_terms

  multiplyMe: (x) ->
    @_constant *= x
    @_terms.each (clv, coeff) => @_terms.put clv, coeff*x
    return this

  times: (x) ->
    if typeof(x) == "number"
      @clone().multiplyMe x
    else
      expr = x
      if @isConstant()
        expr.times @_constant
      else if expr.isConstant()
        @times expr._constant
      else
        throw new Cl.errors.NonlinearExpression()

  plus: (expr) ->
    if expr instanceof Cl.LinearExpression
      @clone().addExpression expr, 1
    else if expr instanceof Cl.Variable
      @clone().addVariable expr, 1

  minus: (expr) ->
    if expr instanceof Cl.LinearExpression
      @clone().addExpression expr, -1
    else if expr instanceof Cl.Variable
      @clone().addVariable expr, -1

  divide: (x) ->
    if typeof(x) == "number"
      throw new Cl.errors.NonlinearExpression() if Cl.approx x, 0
      @times 1/x
    else if x instanceof Cl.LinearExpression
      throw new Cl.errors.NonlinearExpression() unless x.isConstant()
      @times 1/x._constant

  divFrom: (expr) ->
    if (not @isConstant()) or Cl.approx @_constant, 0
      throw new Cl.errors.NonlinearExpression()
    expr.divide @_constant

  subtractFrom: (expr) -> expr.minus this

  addExpression: (expr, n, subject, solver) ->
    if expr instanceof AbstractVariable
      expr = new Cl.LinearExpression expr
    @incrementConstant n*expr.constant()
    n = n || 1
    expr.terms().each (clv, coeff) => @addVariable clv, coeff*n, subject, solver
    return this

  addVariable: (v, c, subject, solver) ->
    c = c || 1
    coeff = @_terms.get v
    if coeff
      new_coefficient = coeff + c
      if Cl.approx new_coefficient, 0

        solver.noteRemovedVariable v, subject if solver
        @_terms.remove v
      else
        @_terms.put v, new_coefficient
    else if not Cl.approx c, 0
      @_terms.put v, c
      solver.noteAddedVariable(v, subject) if solver
    return this

  setVariable: (v, c) ->
    @_terms.put v, c
    return this

  anyPivotableVariable: ->
    throw new Cl.errors.InternalError("anyPivotableVariable called on a constant") if @isConstant()

    @_terms.each (clv, c) -> return clv if clv.isPivotable()
    return null

  substituteOut: (outvar, expr, subject, solver) ->
    multiplier = @_terms.remove outvar
    @incrementConstant multiplier*expr.constant()
    expr.terms().each (clv, coeff) =>
      old_coeff = @_terms.get clv
      if old_coeff
        new_coeff = old_coeff + multiplier*coeff
        if Cl.approx new_coeff, 0
          solver.noteRemovedVariable clv, subject
          @_terms.remove clv
        else
          @_terms.put clv, new_coeff
      else
        @_terms.put clv, multiplier*coeff
        solver.noteAddedVariable clv, subject

  changeSubject: (old_subject, new_subject) -> @_terms.put old_subject, @newSubject new_subject

  newSubject: (subject) ->
    reciprocal = 1 / @_terms.remove subject
    @multiplyMe -reciprocal
    return reciprocal

  coefficientFor: (clv) -> @_terms.get(clv) || 0
  constant: -> @_constant
  set_constant: (@_constant) ->
  terms: -> @_terms
  incrementConstant: (c) -> @_constant += c
  isConstant: -> @_terms.size() == 0

  toString: ->
    bstr = ''
    needsplus = false

    if !Cl.approx(@_constant, 0) || @isConstant()
      bstr += @_constant
      if @isConstant()
        return bstr
      else
        needsplus = true
    @_terms.each (clv, coeff) ->
      bstr += " + " if needsplus
      bstr += coeff + "*" + clv
      needsplus = true
    return bstr
