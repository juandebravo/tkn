# encoding: utf-8

slide <<-EOS, :center
    \e[1mDesign patterns used in Connect. Examples\e[0m

    Iván -DrSlump- Montes
    Jacob Cañadas
    Juan de Bravo
    Francisco Javier Juan
    Gustavo García

    TUGo 2012
EOS

slide <<-EOS, :block
    \e[1mDisclaimers\e[0m:
    - One guy with depth knowledge in \033[92mPHP\033[0m & \033[92mJavascript\033[0m
    - One guy with depth knowledge in \033[92mPython\033[0m
    - One guy with depth knowledge in \033[92mRuby\033[0m
    - One guy with depth knowledge in \033[92mJava\033[0m
    - One guy with depth knowledge in \033[92m.NET\033[0m
    - We love software
    - \033[91mWe hug the tech plan\033[0m
    - One language to rule them all
    - \033[91mGuido\033[0m is our inspiration
EOS

section "Connect code structure review" do
    slide <<-EOS, :block
        - https://pdihub.hi.inet/connect/connect-backend
        - bin
        - \033[91mconnect_backend\033[0m
            - call_control
            - history
            - listener
            - models
            - push_notifications
            - queue
            - sms_control
            - user_profile
        - \033[91mconnect_commons\033[0m
        - dist
        - etc
        - lib
        - scripts
        - \033[91mtests\033[0m
        - .gitignore
        - .venv
        - README.md
        - requirements.txt(-dev and -jenkins)
        - \033[91msettings.cfg(.local)\033[0m
    EOS
end

section "Patterns" do

    slide <<-EOS, :block
        * Unit of work (http://martinfowler.com/eaaCatalog/unitOfWork.html)
    EOS

    slide <<-EOS, :block
        * Before Unit of work came to our code
    EOS

    slide <<-EOS, :code
        call_correlator = None
        sms_correlator = None
        try:
            call_correlator = nes_call_client.start_call_notification(phone_number,
                                        SETTINGS['nes']['calls']['notifications_endpoint'],
                                        ['Answer'])
        except Exception as ex:
            logger.error("Error while subscribing to user calls %s" % ex)
            raise ServiceUnavailableError(ex.message)

    EOS

    slide <<-EOS, :code
        call_correlator = None
        sms_correlator = None
        try:
            call_correlator = nes_call_client.start_call_notification(phone_number,
                                        SETTINGS['nes']['calls']['notifications_endpoint'],
                                        ['Answer'])
        except Exception as ex:
            logger.error("Error while subscribing to user calls %s" % ex)
            raise ServiceUnavailableError(ex.message)

        try:
            sms_correlator = nes_sms_client.start_sms_notification(phone_number,
                                    SETTINGS['nes']['sms']['notifications_endpoint'],
                                    ['Answer'])
        except Exception as ex:
            logger.error("Error while subscribing to user sms %s" % ex)
            try:
                nes_call_client.stop_call_notification(call_correlator)
            except Exception as ex:
                # TODO: create alarm
                logger.error("Unable to stop call notification: %s" % ex)
            raise ServiceUnavailableError(ex.message)
    EOS

    slide <<-EOS, :code
        call_correlator = None
        sms_correlator = None
        try:
            call_correlator = nes_call_client.start_call_notification(phone_number,
                                        SETTINGS['nes']['calls']['notifications_endpoint'],
                                        ['Answer'])
        except Exception as ex:
            logger.error("Error while subscribing to user calls %s" % ex)
            raise ServiceUnavailableError(ex.message)

        try:
            sms_correlator = nes_sms_client.start_sms_notification(phone_number,
                                    SETTINGS['nes']['sms']['notifications_endpoint'],
                                    ['Answer'])
        except Exception as ex:
            logger.error("Error while subscribing to user sms %s" % ex)
            try:
                nes_call_client.stop_call_notification(call_correlator)
            except Exception as ex:
                # TODO: create alarm
                logger.error("Unable to stop call notification: %s" % ex)
            raise ServiceUnavailableError(ex.message)
        try:
            response = oprov_client.activate_service(phone_number)
            logger.info("Activate service to user %s: transaction %s" % (phone_number, response['transaction_id']))
        except Exception as ex:
            logger.error("Unable to activate service: %s" % ex)
            try:
                nes_call_client.stop_call_notification(call_correlator)
            except Exception as ex:
                # TODO: create alarm
                logger.error("Unable to stop call notification: %s" % ex)
            try:
                nes_sms_client.stop_sms_notification(sms_correlator)
            except Exception as ex:
                # TODO: create alarm
                logger.error("Unable to stop sms notification: %s" % ex)
            raise ServiceUnavailableError(ex.message)
        else:
            user.call_correlator_id = call_correlator
            user.sms_correlator_id = sms_correlator
            user.status = Status.PENDING
            user.save()

        return user
    EOS

    slide <<-EOS, :block
        * With unit of work
    EOS

    slide <<-EOS, :code
        steps_list = steps.StepList(user)

        steps_list.add(steps.RegisterJajahUser(extras=metadata))
                  .add(steps.StartCallNotification())
                  .add(steps.StartSmsNotification())
                  .add(steps.RegisterObUser())
                  .add(steps.RegisterDBUser())

        try:
            steps_list.execute()
        except Exception as e:
            bi.log('GC1006', request=settings.request, user=user, reason=str(e))
            raise ServiceUnavailableError()

        return user
    EOS

    slide <<-EOS, :block
        * Transaction like processes can be easily modelled with it
        * Properly encapsulates the code
        * Clean separation of business and integration concerns
        * Easy to modify and refactor
        ----
        Here comes the runner!
        * Note that it is completely agnostic of our business logic
        * Note also that it's in need of a refactor to clean up the implementation
    EOS

    slide <<-EOS, :code
        class StepList(object):
            def __init__(self, obj):
                self.obj = obj
                self._steps = []
                self.rollbacks = []
                self.index = 0

            def add(self, step):
                """ Add a new step to the list, setting the user in the step """
                step.obj = self.obj
                self._steps.append(step)
                return self

            def execute(self):
                """ Execute the process by iterating over the sequence of steps """
                for step in self._steps:
                    try:
                        # If the step is successful we add it to the list of rollback procedures
                        step.commit()
                        self.rollbacks.append(step)
                    except Exception as excommit:
                        logger.error('Error while creating user at step %s: %s' % (step, excommit.message))
                        # Perform the rollback for the committed steps
                        for step in reversed(self.rollbacks):
                            try:
                                logger.info('Rolling back step %s' % step)
                                step.rollback()
                            except Exception as exrollback:
                                # TODO: Inconsistent user state in the system (Trigger alarm???)
                                logger.error('Error while executing rollback for step %s: %s' % (step, exrollback.message))

                        # If a step fail we trigger an error to the client
                        raise Exception(excommit.message)

            def __iter__(self):
                return self

            def next(self):
                """ Iterator """
                if self.index >= len(self._steps):
                    raise StopIteration
                else:
                    self.index += 1
                    return self._steps[self.index - 1]
    EOS

    slide <<-EOS, :center
        * Reactor pattern
    EOS

    slide <<-EOS, :block
        * Twisted
            * Non-blocking I/O            
        * Gevent
            * Non-blocking I/O
            * use greenlets (light threads)
            * Timeouts
    EOS

    slide <<-EOS, :block
        * Twisted: create an HTTP server

        ──────────── 

        - Twisted has a steep learning curve
        - Should be used only when actually needed
    EOS

    slide <<-EOS, :code
        import sys
        from connect_backend.config import backend_parser, config_loader, setup_logger

        from connect_backend.listener.tac_server import setup
        from connect_backend.listener.server import CallResource, SmsResource

        (options, args) = backend_parser(sys.argv)

        config = config_loader(options.config_file)
        setup_logger(config, 'realtime_server')

        rest_config = config.get_section("rest")

        # queue system not configured: hardcoded to redis for real-time servers
        queue_system = 'redis'
        queue_config = config.get_section(queue_system)
        queue_config['system'] = queue_system

        SERVER_LIST = [(CallResource, rest_config["call_control_path"]),
                       (SmsResource, rest_config["sms_control_path"])]

        application = setup(rest_config, queue_config,  server_list=SERVER_LIST)
    EOS

    slide <<-EOS, :block
        * Gevent: patch at socket level

        ────────────         

        - A joy to use :)
        - You still need to think how your application is going to handle its scalability
          and its concurrency model, you just don't have to bother with the low level
          details! 
    EOS

    slide <<-EOS, :code
        from gevent import monkey, GreenletExit
        # Next line is needed in order to make everything work async with gEvent
        monkey.patch_all()
    EOS

    slide <<-EOS, :block
        * Gevent: non blocking HTTP requests
    EOS

    slide <<-EOS, :code
        def __get_from_http(self, id_):
            url = self.url.format(id_)
            return self.http.get(url, config=HTTP_CONFIG, headers=self.headers)
    EOS

    slide <<-EOS, :block
        * Gevent: schedule tasks
    EOS

    slide <<-EOS, :code
        def schedule(param_list, timeout):
            """ Set a function to be run in <timeout> seconds
                param_list should be a tuple of:
                [<redis funtion>,<queue name>,<data>]
            """
            g = gevent.spawn_later(timeout, __schedule, param_list)
            logger.debug("Scheduler function delayed for %d seconds", timeout)
    EOS

    slide <<-EOS, :center
        * Façade pattern
    EOS

    slide <<-EOS, :code
        TODO
    EOS

    slide <<-EOS, :center
        * Adapter pattern
    EOS

    slide <<-EOS, :code
        PHONE_DEVICE =
            {"custom_properties": [
                    {"key": "user_agent",
                     "value": "Connect/1.0 (PM; Apple; iPhone; iPhone OS; 5.1.1;)(41cc33af-920d-5fce-b274-11111111111)"},
                    {"key": "label",
                     "value": "iPhone 5.1.1"}
                    ],
             "name": "iPhone 5.1.1",
             "ids": [{"name": "+sip.instance",
                      "value": "41cc33af-920d-5fce-b274-11111111111"},
                     {"name": "push_token",
                      "value": "foo-bar"}
             ],
             "state": {"status": 1, "URI": "user@voip.gconnect.com; blablabla"},
            }
    EOS

    slide <<-EOS, :code
        # Pair Jajah naming - Connect naming
        ATTRIBUTES_CASTING = (('+sip.instance', 'device_id'),
                            ('push_token', 'push_token'),
                            ('label', 'label'))
        @classmethod
        def create_nice_device_model(cls, device):
            """ Convert device model from the hell to something meaningful """

            def convert(custom_property):
                cp = deepcopy(custom_property)
                cp['name'] = cp.pop('key')
                return cp

            values = device["ids"]
            custom_properties = device.get("custom_properties", [])

            custom_properties = map(convert, custom_properties)
            values.extend(custom_properties)

            # convert from Jajah attributes to connect external attributes
            nice_device = dict((v, DevicesClient.get_value_from_device_ids(values, k))
                            for (k, v) in cls.ATTRIBUTES_CASTING)

            user_agent = DevicesClient.get_value_from_device_ids(values, 'user_agent')

            nice_device['flags'] = parse_user_agent(user_agent)['flags'] if user_agent else ''
            # In case we need to return the current status
            #nice_device['status'] = device['state']['status']
            return nice_device
    EOS

    slide <<-EOS, :code
        PHONE_DEVICE =
            {"custom_properties": [
                    {"key": "user_agent",
                     "value": "Connect/1.0 (PM; Apple; iPhone; iPhone OS; 5.1.1;)(41cc33af-920d-5fce-b274-11111111111)"},
                    {"key": "label",
                     "value": "iPhone 5.1.1"}
                    ],
             "name": "iPhone 5.1.1",
             "ids": [{"name": "+sip.instance",
                      "value": "41cc33af-920d-5fce-b274-11111111111"},
                     {"name": "push_token",
                      "value": "foo-bar"}
             ],
             "state": {"status": 1, "URI": "user@voip.gconnect.com; blablabla"},
            }

        NICE_PHONE_DEVICE = {'push_token': 'foo-bar',
                    'label': 'iPhone 5.1.1',
                    'flags': 'PM',
                    'device_id': '41cc33af-920d-5fce-b274-11111111111'}
    EOS

    slide <<-EOS, :center
        * Single Responsability Principle
    EOS

    slide <<-EOS, :block
        * Funcionality: send push notifications
        * Main blocks:
            - function that receives a list of destinations and a notification type
            - notification class that handles the internal data
            - connection to a decoupled node (via STOMP) to send the push notification to the relevant external platform
    EOS

    slide <<-EOS, :code
        _stomp_push = None
        def push(type_, msisdn, devices, params={}):
            tokens = [":".join((msisdn, x['push_token'])) for x in devices if x.get('push_token')]
            notification = Notification(tokens, type_, params=params)
            message = notification.serialize()

            if not tokens:
                logger.debug('No devices to send notification: %s', message)
            else:
                logger.debug('Notification: %s', message)
                if not _stomp_push(message):
                    logger.warn("Could not send notification %s, due to problems in queue", message)
                    tokens = []

            return len(tokens)
    EOS

    slide <<-EOS, :block
        A great result of applying the Single Responsability Principle is that the
        resulting code will make very obvious what the different concerns are and
        what cross-cutting concerns should be refactored out into a common library.
    EOS    
    
end

section "Metaprogramming" do
    slide <<-EOS, :center
        * Convention over configuration (Dynamic loading)
        * Create functions programmatically (push notifications)
    EOS

    slide <<-EOS, :block
        * Convention over configuration (Dynamic loading)
    EOS

    slide <<-EOS, :code
      TODO

      Note: Use with extreme care. Frameworks can abuse it because they
      offer documentation, are extensively tested and have a large community
      of developers to help. Being able to easily follow the execution logic
      just by looking at the source code is an extremely valuable debugging
      technique that will save you hours and hair :)
    EOS

    slide <<-EOS, :block
        * Create functions programmatically
    EOS

    slide <<-EOS, :code
        def push(type_, msisdn, devices, params={}):
            tokens = [":".join((msisdn, x['push_token'])) for x in devices if x.get('push_token')]
            notification = Notification(tokens, type_, params=params)
            message = notification.serialize()

            if not tokens:
                logger.debug('No devices to send notification: %s', message)
            else:
                logger.debug('Notification: %s', message)
                if not _stomp_push(message):
                    logger.warn("Could not send notification %s, due to problems in queue", message)
                    tokens = []

            return len(tokens)
    EOS

    slide <<-EOS, :block
        * There are three valid types:
            - missed
            - voicemail
            - sms
        * Options:
            1) send always the type from the client
            2) create a method per type
            3) use metaprogramming
    EOS

    slide <<-EOS, :code
        # option 1. send always the type from the client
        push('sms', msisdn, devices, {'msisdn': user['msisdn'], 'sms_body': message['message']})
    EOS

    slide <<-EOS, :code
        # option 2. create a method per type
        def push_sms(msisdn, devices, params={}):
            return push('sms', msisdn, devices, params={})

        push_sms(msisdn, devices, {'msisdn': user['msisdn'], 'sms_body': message['message']})      
    EOS

    slide <<-EOS, :code
        # option 3. use metaprogramming
        NOTIFICATION_TYPES = {'missed': MISSED_CALL, 'voicemail': NEW_VOICEMAIL, 'sms': NEW_MESSAGE}
        
        for k,v in NOTIFICATION_TYPES.items():
            globals()['push_' + k] = partial(push, v)

        push_sms(msisdn, devices, {'msisdn': user['msisdn'], 'sms_body': message['message']})
    EOS
end

section "Django good practices" do

    slide <<-EOS, :block
        * Middlewares
        * create request correlator id
        * exception handling
        * Create a service layer
        * Do not use models native methods in controllers
        * Create resource representation outside controller. Pending how to inject in DjangoRestFramework
    EOS

    slide <<-EOS, :block
        * Some tips on Django:
            It's a no-dependencies framework. Have its source code at hand to easily grep thru it when 
            in trouble.

            Follow its best practices unless you have a good reason to do otherwise. It's an application
            framework and the different components are tied, don't think of it as a components library
            because you'll suffer!
    EOS
end

section "That's all, thanks dudes!" do
end

__END__