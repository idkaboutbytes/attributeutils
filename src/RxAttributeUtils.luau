
--[=[
	Utility functions involving attributes.
	@class RxAttributeUtils
]=]

const ReplicatedStorage = game:GetService('ReplicatedStorage')
const require = require(ReplicatedStorage.Packages.Loader).load()

const Brio = require('Brio')
const Maid = require('Maid')
const Observable = require('Observable')
const Symbol = require('Symbol')

-- selene: allow(unused_variable)
const Rx = require('Rx')

const UNSET_VALUE = Symbol.named('unsetValue')

const RxAttributeUtils = {}

--[=[
	Observes an attribute on an instance.
	@param instance Instance
	@param attributeName string
	@param defaultValue any?
	@return Observable<any>
]=]
@checked
function RxAttributeUtils.observeAttribute<T>(
	instance: Instance,
	attributeName: string,
	defaultValue: T?
): Observable.Observable<T>
	assert(typeof(instance) == 'Instance', 'Bad instance')
	assert(type(attributeName) == 'string', 'Bad attributeName')

	return Observable.new(function(sub)
		const function handleAttributeChanged()
			const attributeValue = instance:GetAttribute(attributeName)
			if attributeValue == nil then
				sub:Fire(defaultValue)
			else
				sub:Fire(attributeValue :: any)
			end
		end

		const connection = instance:GetAttributeChangedSignal(attributeName):Connect(handleAttributeChanged)
		handleAttributeChanged()

		return connection
	end) :: any
end

--[=[
	Observes all the attribute keys that
	@param instance Instance
	@return Observable<Brio<string>>
]=]
@checked
function RxAttributeUtils.observeAttributeKeysBrio(instance: Instance): Observable.Observable<Brio.Brio<string>>
	assert(typeof(instance) == 'Instance', 'Bad instance')

	return Observable.new(function(sub)
		const maid = Maid.new()

		const attributeNameToBrio: { [string]: any } = {}

		const function handleAttributeChanged(attributeName: string, attributeValue: any)
			if attributeValue == nil then
				const brio = attributeNameToBrio[attributeName]
				if brio then
					attributeNameToBrio[attributeName] = nil
					maid[brio] = nil
				end
			else
				if not attributeNameToBrio[attributeName] then
					const brio: any = Brio.new(attributeName)
					attributeNameToBrio[attributeName] = brio
					maid[brio] = brio
					sub:Fire(brio)
				end
			end
		end

		maid:GiveTask(instance.AttributeChanged:Connect(function(attributeName)
			handleAttributeChanged(attributeName, instance:GetAttribute(attributeName))
		end))

		for attributeName, attributeValue in pairs(instance:GetAttributes()) do
			if not sub:IsPending() then
				break
			end

			-- TODO: Maybe we technically need to requery here but it's expensive
			handleAttributeChanged(attributeName, attributeValue)
		end

		return maid
	end) :: any
end

--[=[
	Observes all the attribute keys for an instance

	@param instance Instance
	@return Observable<string>
]=]
@checked
function RxAttributeUtils.observeAttributeKeys(instance: Instance): Observable.Observable<string>
	assert(typeof(instance) == 'Instance', 'Bad instance')

	return Observable.new(function(sub)
		const maid = Maid.new()

		maid:GiveTask(instance.AttributeChanged:Connect(function(attribute)
			sub:Fire(attribute)
		end))

		for attribute, _ in pairs(instance:GetAttributes()) do
			if not sub:IsPending() then
				break
			end

			sub:Fire(attribute)
		end

		return maid
	end) :: any
end

--[=[
	Observes an attribute on an instance with a conditional statement.
	@param instance Instance
	@param attributeName string
	@param condition function | nil
	@return Observable<Brio<any>>
]=]
@checked
function RxAttributeUtils.observeAttributeBrio<T>(
	instance: Instance,
	attributeName: string,
	condition: Rx.Predicate<T>?
): Observable.Observable<Brio.Brio<T>>
	assert(typeof(instance) == 'Instance', 'Bad instance')
	assert(type(attributeName) == 'string', 'Bad attributeName')

	return Observable.new(function(sub)
		const maid = Maid.new()
		local lastValue = UNSET_VALUE

		const function handleAttributeChanged()
			const attributeValue = instance:GetAttribute(attributeName)

			-- Deferred events can cause multiple values to be queued at once
			-- but we operate at this post-deferred layer, so lets only output
			-- reflected values.
			if lastValue ~= attributeValue then
				lastValue = attributeValue

				if not condition or condition(attributeValue :: T) then
					const brio = Brio.new(attributeValue)
					maid._lastBrio = brio

					-- The above line can cause us to be overwritten so make sure before firing.
					if maid._lastBrio == brio then
						sub:Fire(brio)
					end
				else
					maid._lastBrio = nil
				end
			end
		end

		maid:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(handleAttributeChanged))
		handleAttributeChanged()

		return maid
	end) :: any
end

return RxAttributeUtils
