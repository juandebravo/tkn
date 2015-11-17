# encoding: utf-8

center <<-EOS
  \e[1mThe \e[92myield\e[0m\e[1m statement/expression in python\e[0m

  Juan de Bravo

  BIGeeklies
  Telefonica I+D
  November 2015
EOS

block <<-EOS
  - Generators (when god thought preventing state outside the function was a good idea)
  - Coroutines (when god thought getting a new value to resume a generator was a good idea)
  - Multiple generators
  - async.io
EOS

section "\e[92mGenerators\e[0m" do
  block <<-EOS
  \e[92mGENERATORS\e[0m:\n
  "Provide a kind of function that can return an \e[91mintermediate result\e[0m
  ("the next value") to its caller, but maintaining the function's
  \e[91mlocal state\e[0m so that the function can be resumed again right where
  it left off."

  \e[1mhttps://www.python.org/dev/peps/pep-0255/\e[0m

  Added in python 2.2
  EOS

  block <<-EOS
  \e[92mGENERATORS\e[0m:\n
  A function that contains a \e[1myield statement\e[0m is called a \e[91mgenerator function\e[0m.\n
  \e[1mWhen a generator function is called, the actual arguments are bound to
  function-local formal argument names in the usual way, but no code in
  the body of the function is executed.\e[0m\n
  Each time the \e[1m.next()\e[0m method of a generator-iterator is invoked, the
  code in the body of the generator-function is executed until a yield
  or return statement (see below) is encountered, or until the end of
  the body is reached.\n
  Generator is \e[1mexhausted\e[0m if:\n
  - return statement is executed
  - StopIteration exception is raised
  - end of generator function

  Important: \e[1mA generator can be consumed only once\e[0m
  EOS

  code <<-EOS
    def countdown(n):
        print "Counting down from %s to 0" % n
        # Initiate i (local state)
        i = n
        while i >= 0:
            # Send i value to the caller
            yield i
            # Execution is resumed here
            # when caller requests the next value
            i = i - 1

    # Using the generator
    for i in countdown(5):
        print i

    Counting down from 5 to 0
    5
    4
    3
    2
    1
    0
  EOS

end

section "\e[92mCoroutines\e[0m" do
  block <<-EOS
    Coroutines are \e[91mspecial functions\e[0m that differ from usual ones in four aspects:

    - exposes \e[1mseveral entry points\e[0m to a function.
      An entry point is the line of code inside the function where it will take
      control over the execution.
    - can receive a \e[1mdifferent input in every entry point\e[0m while executing the coroutine.
    - can return \e[1mdifferent outputs\e[0m as response to the different entry points.
    - can \e[1msave control state\e[0m between entry points calls.

    https://www.python.org/dev/peps/pep-0342/

    Added in python 2.5
  EOS

  code <<-EOS
    def concatenate(_str):
        """
        Coroutine that receives a new string in every
        iteration and concatenates to the original one
        """
        temp = None

        while temp != '':
            # Wait for a new input (suspend the coroutine)...
            # We could send a value as well
            temp = yield
            # ... and save control state (resume the execution)
            _str += temp
            print _str

    # Instantiate a new coroutine...
    a = concatenate('foo')

    # ... and "move" the coroutine state till the `yield` keyword
    a.next()
    # similar to a.send(None)

    while True:
        try:
            # Send the raw input from the user to the coroutine...
            a.send(raw_input())
        except StopIteration:
            # ... and capture the coroutine end by means
            # of StopIteration exception
            break
  EOS

  block <<-EOS
    \e[91mWashington\e[0m\n
    Coroutines execution via a chainable API.

    Washington is a simple library implemented with the only
    intention of having fun while learning about how to use coroutines in python.

    - https://github.com/juandebravo/washington

    \e[92mMust read article about functional programming in python!\e[0m

    http://maryrosecook.com/blog/post/a-practical-introduction-to-functional-programming
  EOS

  code <<-EOS
    # Imperative way
    for u in open('file.txt'):
        d = dict(zip(('alias', 'email', 'location'), u.split('|', 2)))
        patc = re.compile(r'^[^u]+u')
        if patc.search(d['alias']):
            os.sys.stdout.write(d['alias'])  # Python 2/3 compliance
            with open('result2.log', 'a') as f:
                 f.write(d['alias'])

    # Washington
    # Coroutines using a chainable API
    filter_users_chain = (pipeline(open('file.txt')).
                          create_dict(('alias', 'email', 'location')).
                          filter_by('alias', r'^[^u]+u').
                          pluck('alias').
                          dumper(os.sys.stdout.write).
                          print_name('result.log'))

    filter_users_chain()
  EOS
end

section "\e[92mDelegating to a Subgenerator\e[0m" do
  block <<-EOS
    Syntax for \e[91ma generator to delegate\e[0m part of its operations
    to another generator.

    https://www.python.org/dev/peps/pep-0380/

    Added in python 3.3
  EOS

  code <<-EOS
      #!/usr/bin/env python3

      def characters_range(initial, end):
          for i in range(initial, end):
              yield chr(i)


      def numbers_alphabet():
          # numbers
          yield from characters_range(48, 58)

          # uppercase
          yield from characters_range(65, 91)

          # lowercase
          yield from characters_range(97, 123)


      if __name__ == '__main__':
          for x in numbers_alphabet():
              print(x)
  EOS
end

section "That's all, thanks dudes!" do
end
