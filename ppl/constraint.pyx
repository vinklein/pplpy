# distutils: language = c++
# distutils: libraries = gmp gmpxx ppl m
from __future__ import absolute_import, print_function

from cpython.int cimport PyInt_CheckExact
from cpython.long cimport PyLong_CheckExact
include "cysignals/signals.pxi"

from .cygmp.pylong cimport mpz_get_pyintlong, mpz_set_pylong

try:
    from sage.all import Rational
    def Fraction(p,q):
        return Rational((p,q))
except ImportError:
    from fractions import Fraction

# PPL can use floating-point arithmetic to compute integers
cdef extern from "ppl.hh" namespace "Parma_Polyhedra_Library":
    cdef void set_rounding_for_PPL()
    cdef void restore_pre_PPL_rounding()

# but with PPL's rounding the gsl will be very unhappy; must turn off!
restore_pre_PPL_rounding()

####################################################
### Constraint ######################################
####################################################

####################################################
cdef class Constraint(object):
    """
    Wrapper for PPL's ``Constraint`` class.

    An object of the class ``Constraint`` is either:

    * an equality :math:`\sum_{i=0}^{n-1} a_i x_i + b = 0`

    * a non-strict inequality :math:`\sum_{i=0}^{n-1} a_i x_i + b \geq 0`

    * a strict inequality :math:`\sum_{i=0}^{n-1} a_i x_i + b > 0`

    where :math:`n` is the dimension of the space, :math:`a_i` is the integer
    coefficient of variable :math:`x_i`, and :math:`b_i` is the integer
    inhomogeneous term.

    INPUT/OUTPUT:

    You construct constraints by writing inequalities in
    :class:`Linear_Expression`. Do not attempt to manually construct
    constraints.

    Examples:

    >>> from ppl import Constraint, Variable, Linear_Expression
    >>> x = Variable(0)
    >>> y = Variable(1)
    >>> 5*x-2*y >  x+y-1
    4*x0-3*x1+1>0
    >>> 5*x-2*y >= x+y-1
    4*x0-3*x1+1>=0
    >>> 5*x-2*y == x+y-1
    4*x0-3*x1+1==0
    >>> 5*x-2*y <= x+y-1
    -4*x0+3*x1-1>=0
    >>> 5*x-2*y <  x+y-1
    -4*x0+3*x1-1>0
    >>> x > 0
    x0>0

    Special care is needed if the left hand side is a constant:

    >>> 0 == 1    # watch out!
    False
    >>> Linear_Expression(0) == 1
    -1==0
    """
    def __cinit__(self, do_not_construct_manually=False):
        """
        The Cython constructor.

        See :class:`Constraint` for documentation.

        Tests:

            >>> from ppl import Constraint, Variable, Linear_Expression
            >>> x = Variable(0)
            >>> x>0   # indirect doctest
            x0>0
        """
        assert(do_not_construct_manually)
        self.thisptr = NULL

    def __dealloc__(self):
        """
        The Cython destructor.
        """
        assert self.thisptr!=NULL, 'Do not construct Constraints manually!'
        del self.thisptr

    def __repr__(self):
        """
        Return a string representation of the constraint.

        OUTPUT:

        String.

        Examples:

        >>> from ppl import Constraint, Variable
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> (2*x-y+5 >  x).__repr__()
        'x0-x1+5>0'
        >>> (2*x-y+5 == x).__repr__()
        'x0-x1+5==0'
        >>> (2*x-y+5 >= x).__repr__()
        'x0-x1+5>=0'
        """
        e = sum(self.coefficient(x)*x
                for x in (Variable(i)
                          for i in range(self.space_dimension())))
        e += self.inhomogeneous_term()
        s = repr(e)
        t = self.thisptr.type()
        if t == EQUALITY:
            s += '==0'
        elif t == NONSTRICT_INEQUALITY:
            s += '>=0'
        elif t == STRICT_INEQUALITY:
            s += '>0'
        else:
            raise RuntimeError
        return s

    def space_dimension(self):
        r"""
        Return the dimension of the vector space enclosing ``self``.

        OUTPUT:

        Integer.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> (x>=0).space_dimension()
        1
        >>> (y==1).space_dimension()
        2
        """
        return self.thisptr.space_dimension()

    def type(self):
        r"""
        Return the constraint type of ``self``.

        OUTPUT:

        String. One of ``'equality'``, ``'nonstrict_inequality'``, or
        ``'strict_inequality'``.

        Examples:

            >>> from ppl import Variable
            >>> x = Variable(0)
            >>> (x==0).type()
            'equality'
            >>> (x>=0).type()
            'nonstrict_inequality'
            >>> (x>0).type()
            'strict_inequality'
        """
        t = self.thisptr.type()
        if t == EQUALITY:
            return 'equality'
        elif t == NONSTRICT_INEQUALITY:
            return 'nonstrict_inequality'
        elif t == STRICT_INEQUALITY:
            return 'strict_inequality'
        else:
            raise RuntimeError

    def is_equality(self):
        r"""
        Test whether ``self`` is an equality.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is an
        equality constraint.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==0).is_equality()
        True
        >>> (x>=0).is_equality()
        False
        >>> (x>0).is_equality()
        False
        """
        return self.thisptr.is_equality()

    def is_inequality(self):
        r"""
        Test whether ``self`` is an inequality.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is an
        inequality constraint, either strict or non-strict.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==0).is_inequality()
        False
        >>> (x>=0).is_inequality()
        True
        >>> (x>0).is_inequality()
        True
        """
        return self.thisptr.is_inequality()

    def is_nonstrict_inequality(self):
        r"""
        Test whether ``self`` is a non-strict inequality.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is an
        non-strict inequality constraint.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==0).is_nonstrict_inequality()
        False
        >>> (x>=0).is_nonstrict_inequality()
        True
        >>> (x>0).is_nonstrict_inequality()
        False
        """
        return self.thisptr.is_nonstrict_inequality()

    def is_strict_inequality(self):
        r"""
        Test whether ``self`` is a strict inequality.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is an
        strict inequality constraint.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==0).is_strict_inequality()
        False
        >>> (x>=0).is_strict_inequality()
        False
        >>> (x>0).is_strict_inequality()
        True
        """
        return self.thisptr.is_strict_inequality()

    def coefficient(self, Variable v):
        """
        Return the coefficient of the variable ``v``.

        INPUT:

        - ``v`` -- a :class:`Variable`.

        OUTPUT:

        An integer.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> ineq = 3*x+1 > 0
        >>> ineq.coefficient(x)
        3
        >>> y = Variable(1)
        >>> ineq = 3**50 * y + 2 > 1
        >>> str(ineq.coefficient(y))
        '717897987691852588770249'
        >>> ineq.coefficient(x)
        0
        """
        return mpz_get_pyintlong(self.thisptr.coefficient(v.thisptr[0]).get_mpz_t())

    def coefficients(self):
        """
        Return the coefficients of the constraint.

        See also :meth:`coefficient`.

        OUTPUT:

        A tuple of integers of length :meth:`space_dimension`.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0);  y = Variable(1)
        >>> ineq = ( 3*x+5*y+1 ==  2);  ineq
        3*x0+5*x1-1==0
        >>> ineq.coefficients()
        (3, 5)
        """
        cdef int d = self.space_dimension()
        cdef int i
        coeffs = []
        for i in range(0,d):
            coeffs.append(mpz_get_pyintlong(self.thisptr.coefficient(PPL_Variable(i)).get_mpz_t()))
        return tuple(coeffs)

    def inhomogeneous_term(self):
        """
        Return the inhomogeneous term of the constraint.

        OUTPUT:

        Integer.

        Examples:

        >>> from ppl import Variable
        >>> y = Variable(1)
        >>> ineq = 10+y > 9
        >>> ineq
        x1+1>0
        >>> ineq.inhomogeneous_term()
        1
        >>> ineq = 2**66 + y > 0
        >>> str(ineq.inhomogeneous_term())
        '73786976294838206464'
        """
        return mpz_get_pyintlong(self.thisptr.inhomogeneous_term().get_mpz_t())

    def is_tautological(self):
        r"""
        Test whether ``self`` is a tautological constraint.

        A tautology can have either one of the following forms:

        * an equality: :math:`\sum 0 x_i + 0 = 0`,

        * a non-strict inequality: :math:`\sum 0 x_i + b \geq 0` with `b\geq 0`, or

        * a strict inequality: :math:`\sum 0 x_i + b > 0` with `b> 0`.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is a
        tautological constraint.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==0).is_tautological()
        False
        >>> (0*x>=0).is_tautological()
        True
        """
        return self.thisptr.is_tautological()

    def is_inconsistent(self):
        r"""
        Test whether ``self`` is an inconsistent constraint, that is, always false.

        An inconsistent constraint can have either one of the
        following forms:

        * an equality: :math:`\sum 0 x_i + b = 0` with `b\not=0`,

        * a non-strict inequality: :math:`\sum 0 x_i + b \geq 0` with `b< 0`, or

        * a strict inequality: :math:`\sum 0 x_i + b > 0` with `b\leq 0`.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` is an
        inconsistent constraint.

        Examples:

        >>> from ppl import Variable
        >>> x = Variable(0)
        >>> (x==1).is_inconsistent()
        False
        >>> (0*x>=1).is_inconsistent()
        True
        """
        return self.thisptr.is_inconsistent()

    def is_equivalent_to(self, Constraint c):
        r"""
        Test whether ``self`` and ``c`` are equivalent.

        INPUT:

        - ``c`` -- a :class:`Constraint`.

        OUTPUT:

        Boolean. Returns ``True`` if and only if ``self`` and ``c``
        are equivalent constraints.

        Note that constraints having different space dimensions are
        not equivalent. However, constraints having different types
        may nonetheless be equivalent, if they both are tautologies or
        inconsistent.

        Examples:

        >>> from ppl import Variable, Linear_Expression
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> (x > 0).is_equivalent_to(Linear_Expression(0) < x)
        True
        >>> (x > 0).is_equivalent_to(0*y < x)
        False
        >>> (0*x > 1).is_equivalent_to(0*x == -2)
        True
        """
        return self.thisptr.is_equivalent_to(c.thisptr[0])

    def ascii_dump(self):
        r"""
        Write an ASCII dump to stderr.

        Examples:

        >>> cmd  = 'from ppl import Linear_Expression, Variable\n'
        >>> cmd += 'x = Variable(0)\n'
        >>> cmd += 'y = Variable(1)\n'
        >>> cmd += 'e = (3*x+2*y+1 > 0)\n'
        >>> cmd += 'e.ascii_dump()\n'
        >>> import subprocess, sys
        >>> proc = subprocess.Popen([sys.executable, '-c', cmd], stderr=subprocess.PIPE)
        >>> out, err = proc.communicate()
        >>> print(str(err.decode('ascii')))
        size 4 1 3 2 -1 ...
        <BLANKLINE>
        """
        self.thisptr.ascii_dump()

    def OK(self):
        """
        Check if all the invariants are satisfied.

        Examples:

        >>> from ppl import Linear_Expression, Variable
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> ineq = (3*x+2*y+1>=0)
        >>> ineq.OK()
        True
        """
        return self.thisptr.OK()

    def __reduce__(self):
        """
        Pickle object.

        Examples:

        >>> from ppl import Linear_Expression, Variable
        >>> from pickle import loads, dumps
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> loads(dumps(3*x+2*y+1>=5))
        3*x0+2*x1-4>=0
        >>> loads(dumps(3*x+2*y+1>5))
        3*x0+2*x1-4>0
        >>> loads(dumps(3*x+2*y+1==5))
        3*x0+2*x1-4==0
        """
        le = Linear_Expression(self.coefficients(), self.inhomogeneous_term())
        if self.is_nonstrict_inequality():
            return (inequality, (le, ))
        elif self.is_strict_inequality():
            return (strict_inequality, (le, ))
        elif self.is_equality():
            return (equation, (le, ))
        else:
            raise RuntimeError


####################################################
def inequality(expression):
    """
    Constuct an inequality.

    INPUT:

    - ``expression`` -- a :class:`Linear_Expression`.

    OUTPUT:

    The inequality ``expression`` >= 0.

    Examples:

    >>> from ppl import Variable, inequality
    >>> y = Variable(1)
    >>> 2*y+1 >= 0
    2*x1+1>=0
    >>> inequality(2*y+1)
    2*x1+1>=0
    """
    return expression >= 0


####################################################
def strict_inequality(expression):
    """
    Constuct a strict inequality.

    INPUT:

    - ``expression`` -- a :class:`Linear_Expression`.

    OUTPUT:

    The inequality ``expression`` > 0.

    Examples:

    >>> from ppl import Variable, strict_inequality
    >>> y = Variable(1)
    >>> 2*y+1 > 0
    2*x1+1>0
    >>> strict_inequality(2*y+1)
    2*x1+1>0
    """
    return expression > 0


####################################################
def equation(expression):
    """
    Constuct an equation.

    INPUT:

    - ``expression`` -- a :class:`Linear_Expression`.

    OUTPUT:

    The equation ``expression`` == 0.

    Examples:

    >>> from ppl import Variable, equation
    >>> y = Variable(1)
    >>> 2*y+1 == 0
    2*x1+1==0
    >>> equation(2*y+1)
    2*x1+1==0
    """
    return expression == 0



####################################################
### Constraint_System  ##############################
####################################################


####################################################
cdef class Constraint_System(object):
    """
    Wrapper for PPL's ``Constraint_System`` class.

    An object of the class Constraint_System is a system of
    constraints, i.e., a multiset of objects of the class
    Constraint. When inserting constraints in a system, space
    dimensions are automatically adjusted so that all the constraints
    in the system are defined on the same vector space.

    Examples:

        >>> from ppl import Constraint_System, Variable
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> cs = Constraint_System( 5*x-2*y > 0 )
        >>> cs.insert( 6*x < 3*y )
        >>> cs.insert( x >= 2*x-7*y )
        >>> cs
        Constraint_System {5*x0-2*x1>0, ...}
        >>> cs[0]
        5*x0-2*x1>0
    """
    def __cinit__(self, arg=None):
        """
        The Cython constructor.

        See :class:`Constraint_System` for documentation.

        Tests:

        >>> from ppl import Constraint_System
        >>> Constraint_System()
        Constraint_System {}
        """
        if arg is None:
            self.thisptr = new PPL_Constraint_System()
        elif isinstance(arg, Constraint):
            g = <Constraint>arg
            self.thisptr = new PPL_Constraint_System(g.thisptr[0])
        elif isinstance(arg, Constraint_System):
            gs = <Constraint_System>arg
            self.thisptr = new PPL_Constraint_System(gs.thisptr[0])
        elif isinstance(arg, (list,tuple)):
            self.thisptr = new PPL_Constraint_System()
            for constraint in arg:
                self.insert(constraint)
        else:
            raise TypeError('cannot initialize from {!r}'.format(arg))

    def __dealloc__(self):
        """
        The Cython destructor.
        """
        del self.thisptr

    def space_dimension(self):
        r"""
        Return the dimension of the vector space enclosing ``self``.

        OUTPUT:

        Integer.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System( x>0 )
        >>> cs.space_dimension()
        1
        """
        return self.thisptr.space_dimension()

    def has_equalities(self):
        r"""
        Tests whether ``self`` contains one or more equality constraints.

        OUTPUT:

        Boolean.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System()
        >>> cs.insert( x>0 )
        >>> cs.insert( x<0 )
        >>> cs.has_equalities()
        False
        >>> cs.insert( x==0 )
        >>> cs.has_equalities()
        True
        """
        return self.thisptr.has_equalities()

    def has_strict_inequalities(self):
        r"""
        Tests whether ``self`` contains one or more strict inequality constraints.

        OUTPUT:

        Boolean.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System()
        >>> cs.insert( x>=0 )
        >>> cs.insert( x==-1 )
        >>> cs.has_strict_inequalities()
        False
        >>> cs.insert( x>0 )
        >>> cs.has_strict_inequalities()
        True
        """
        return self.thisptr.has_strict_inequalities()

    def clear(self):
        r"""
        Removes all constraints from the constraint system and sets its
        space dimension to 0.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System(x>0)
        >>> cs
        Constraint_System {x0>0}
        >>> cs.clear()
        >>> cs
        Constraint_System {}
        """
        self.thisptr.clear()

    def insert(self, Constraint c):
        """
        Insert ``c`` into the constraint system.

        INPUT:

        - ``c`` -- a :class:`Constraint`.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System()
        >>> cs.insert( x>0 )
        >>> cs
        Constraint_System {x0>0}
        """
        self.thisptr.insert(c.thisptr[0])

    def empty(self):
        """
        Return ``True`` if and only if ``self`` has no constraints.

        OUTPUT:

        Boolean.

        Examples:

        >>> from ppl import Variable, Constraint_System, point
        >>> x = Variable(0)
        >>> cs = Constraint_System()
        >>> cs.empty()
        True
        >>> cs.insert( x>0 )
        >>> cs.empty()
        False
        """
        return self.thisptr.empty()

    def ascii_dump(self):
        r"""
        Write an ASCII dump to stderr.

        Examples:

        >>> cmd  = 'from ppl import Constraint_System, Variable\n'
        >>> cmd += 'x = Variable(0)\n'
        >>> cmd += 'y = Variable(1)\n'
        >>> cmd += 'cs = Constraint_System( 3*x > 2*y+1 )\n'
        >>> cmd += 'cs.ascii_dump()\n'
        >>> import subprocess, sys
        >>> proc = subprocess.Popen([sys.executable, '-c', cmd], stderr=subprocess.PIPE)
        >>> out, err = proc.communicate()
        >>> print(str(err.decode('ascii')))
        topology NOT_NECESSARILY_CLOSED
        ...
        <BLANKLINE>
        """
        self.thisptr.ascii_dump()

    def OK(self):
        """
        Check if all the invariants are satisfied.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> cs = Constraint_System( 3*x+2*y+1 <= 10 )
        >>> cs.OK()
        True
        """
        return self.thisptr.OK()

    def __len__(self):
        """
        Return the number of constraints in the system.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System( x>0 )
        >>> cs.insert( x<1 )
        >>> len(cs)
        2
        """
        return sum(1 for c in self)

    def __iter__(self):
        """
        Iterate through the constraints of the system.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System( x>0 )
        >>> iter = cs.__iter__()
        >>> next(iter)
        x0>0
        >>> list(cs)   # uses __iter__() internally
        [x0>0]
        """
        return Constraint_System_iterator(self)

    def __getitem__(self, int k):
        """
        Return the k-th constraint.

        The correct way to read the individual constraints is to
        iterate over the constraint system. This method is for
        convenience only.

        INPUT:

        - ``k`` -- integer. The index of the constraint.

        OUTPUT:

        The `k`-th constraint of the constraint system.

        Examples:

        >>> from ppl import Variable, Constraint_System
        >>> x = Variable(0)
        >>> cs = Constraint_System( x>0 )
        >>> cs.insert( x<1 )
        >>> cs
        Constraint_System {x0>0, -x0+1>0}
        >>> cs[0]
        x0>0
        >>> cs[1]
        -x0+1>0
        """
        if k < 0:
            raise IndexError('index must be nonnegative')
        iterator = iter(self)
        try:
            for i in range(k):
                next(iterator)
        except StopIteration:
            raise IndexError('index is past-the-end')
        return next(iterator)

    def __repr__(self):
        r"""
        Return a string representation of the constraint system.

        OUTPUT:

        A string.

        Examples:

        >>> from ppl import Constraint_System, Variable
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> cs = Constraint_System([3*x+2*y+1 < 3, 0*x>x+1])
        >>> cs.__repr__()
        'Constraint_System {-3*x0-2*x1+2>0, -x0-1>0}'
        """
        s = 'Constraint_System {'
        s += ', '.join([ repr(c) for c in self ])
        s += '}'
        return s

    def __reduce__(self):
        """
        Pickle object.

        Tests:

        >>> from ppl import Constraint_System, Variable
        >>> from pickle import loads, dumps
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> cs = Constraint_System([3*x+2*y+1 < 3, 0*x>x+1]);  cs
        Constraint_System {-3*x0-2*x1+2>0, -x0-1>0}
        >>> loads(dumps(cs))
        Constraint_System {-3*x0-2*x1+2>0, -x0-1>0}
        """
        return (Constraint_System, (tuple(self), ))


####################################################
### Constraint_System_iterator #####################
####################################################

####################################################
cdef class Constraint_System_iterator(object):
    """
    Wrapper for PPL's ``Constraint_System::const_iterator`` class.

    Examples:

        >>> from ppl import Constraint_System, Variable, Constraint_System_iterator
        >>> x = Variable(0)
        >>> y = Variable(1)
        >>> cs = Constraint_System( 5*x < 2*y )
        >>> cs.insert( 6*x-y == 0 )
        >>> cs.insert( x >= 2*x-7*y )
        >>> next(Constraint_System_iterator(cs))
        -5*x0+2*x1>0
        >>> list(cs)
        [-5*x0+2*x1>0, 6*x0-x1==0, -x0+7*x1>=0]
    """
    def __cinit__(self, Constraint_System cs):
        """
        The Cython constructor.

        See :class:`Constraint_System_iterator` for documentation.

        Tests:

        >>> from ppl import Constraint_System, Constraint_System_iterator
        >>> iter = Constraint_System_iterator( Constraint_System() )   # indirect doctest
        """
        self.cs = cs
        self.csi_ptr = init_cs_iterator(cs.thisptr[0])

    def __dealloc__(self):
        """
        The Cython destructor.
        """
        delete_cs_iterator(self.csi_ptr)

    def __next__(Constraint_System_iterator self):
        r"""
        The next iteration.

        OUTPUT:

        A :class:`Generator`.

        Examples:

        >>> from ppl import Constraint_System, Variable, Constraint_System_iterator
        >>> x = Variable(0)
        >>> cs = Constraint_System( x > 0 )
        >>> cs.insert ( 2*x <= -3)
        >>> it = iter(cs)
        >>> next(it)
        x0>0
        >>> next(it)
        -2*x0-3>=0
        >>> next(it)
        Traceback (most recent call last):
        ...
        StopIteration
        """
        if is_end_cs_iterator((<Constraint_System>self.cs).thisptr[0], self.csi_ptr):
            raise StopIteration
        return _wrap_Constraint(next_cs_iterator(self.csi_ptr))