require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkSettings do
    let(:network_settings) do
      NetworkSettings.new(
        'fake-job',
        'fake-deployment',
        {'gateway' => 'net_a'},
        reservations,
        {'net_a' => {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}},
        az,
        3,
        'uuid-1',
        'bosh1.tld',
      )
    end
    let(:instance_group) do
      instance_group = InstanceGroup.new(logger)
      instance_group.name = 'fake-job'
      instance_group
    end

    let(:az) { AvailabilityZone.new('az-1', {'foo' => 'bar'}) }
    let(:instance) { Instance.create_from_instance_group(instance_group, 3, 'started', plan, {}, az, logger) }
    let(:reservations) {
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, manual_network)
      reservation.resolve_ip('10.0.0.6')
      [reservation]
    }
    let(:manual_network) {
      ManualNetwork.parse({
          'name' => 'net_a',
          'dns' => ['1.2.3.4'],
          'subnets' => [{
              'range' => '10.0.0.1/24',
              'gateway' => '10.0.0.1',
              'dns' => ['1.2.3.4'],
              'cloud_properties' => {'foo' => 'bar'}
            }
          ]
        },
        [],
        GlobalNetworkResolver.new(plan, [], logger),
        logger
      )
    }
    let(:plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }

    describe '#to_hash' do
      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)] }

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          expect(network_settings.to_hash).to eql(
            {
              'net_a' => {
                'type' => 'dynamic',
                'cloud_properties' => {
                  'foo' => 'bar'
                },
                'dns' => ['1.2.3.4'],
                'default' => ['gateway'],
                'ip' => '10.0.0.6',
                'netmask' => '255.255.255.0',
                'gateway' => '10.0.0.1'}
            })
        end
      end

      context 'manual network' do
        describe '#network_address' do
          let(:prefer_dns_addresses) { true }
          it 'returns the ip address for manual networks on the instance' do
            expect(network_settings.network_address(prefer_dns_addresses)).to eq('10.0.0.6')
          end
        end
      end
    end

    describe '#network_address' do
      context 'when prefer_dns_entry is set to true' do
        let (:prefer_dns_entry) {true}

        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record for that network' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
            DynamicNetwork.new('net_a', subnets, logger)
          end
          let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)]}

          context 'when local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end
        end
      end

      context 'addressable network' do
        let(:network_settings) do
          NetworkSettings.new(
            'fake-job',
            'fake-deployment',
            {'gateway' => 'net_a', 'addressable' => 'net_public'},
            [reservation],
            {'net_a' => {'ip' => '10.0.0.6', 'netmask' => '255.255.255.0', 'gateway' => '10.0.0.1'}},
            az,
            3,
            'uuid-1',
            'bosh1.tld',
          )
        end
      end

      context 'when prefer_dns_entry is set to false' do
        let (:prefer_dns_entry) {false}

        context 'when it is a manual network' do
          context 'and local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the ip address for the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('10.0.0.6')
            end
          end
        end

        context 'when it is a dynamic network' do
          let(:dynamic_network) do
            subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
            DynamicNetwork.new('net_a', subnets, logger)
          end
          let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)]}

          context 'when local dns is disabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end

          context 'when local dns is enabled' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
            end

            it 'returns the dns record name of the instance' do
              expect(network_settings.network_address(prefer_dns_entry)).to eq('uuid-1.fake-job.net-a.fake-deployment.bosh1.tld')
            end
          end
        end
      end
    end

    describe '#dns_record_info' do
      it 'includes both id and uuid records' do
        expect(network_settings.dns_record_info).to eq({
          '3.fake-job.net-a.fake-deployment.bosh1.tld' => '10.0.0.6',
          'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld' => '10.0.0.6',
        })
      end
    end

    describe '#network_addresses' do
      context 'dynamic network' do
        let(:dynamic_network) do
          subnets = [DynamicNetworkSubnet.new(['1.2.3.4'], {'foo' => 'bar'}, 'az-1')]
          DynamicNetwork.new('net_a', subnets, logger)
        end

        let(:reservations) {[Bosh::Director::DesiredNetworkReservation.new_dynamic(instance.model, dynamic_network)]}
        context 'when DNS entries are requested' do
          it 'includes the network name and domain record' do
            expect(network_settings.network_addresses(true)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld', })
          end
        end
        context 'when DNS entries are NOT requested' do
          it 'still includes the network name and domain record' do
            expect(network_settings.network_addresses(false)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld', })
          end
        end
      end

      context 'when network is manual' do
        context 'and local dns is disabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(false)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name and ip' do
              expect(network_settings.network_addresses(true)).to eq({'net_a' => '10.0.0.6'})
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name and ip' do
              expect(network_settings.network_addresses(false)).to eq({'net_a' => '10.0.0.6'})
            end
          end
        end

        context 'and local dns is enabled' do
          before do
            allow(Bosh::Director::Config).to receive(:local_dns_enabled?).and_return(true)
          end

          context 'and DNS entries are requested' do
            it 'includes the network name dns record' do
              expect(network_settings.network_addresses(true)).to eq({'net_a' => 'uuid-1.fake-job.net-a.fake-deployment.bosh1.tld'})
            end
          end

          context 'and DNS entries are NOT requested' do
            it 'includes the network name dns record' do
              expect(network_settings.network_addresses(false)).to eq({'net_a' => '10.0.0.6'})
            end
          end
        end
      end
    end
  end
end
