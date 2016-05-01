require 'lfs'
require 'torch'

-- Make sure that directory structure is always the same
if (string.match(lfs.currentdir(), "/specs$")) then
  lfs.chdir("..")
end

-- Include Dataframe lib
paths.dofile('init.lua')

-- Go into specs so that the loading of CSV:s is the same as always
lfs.chdir("specs")

describe("Dataframe class", function()

	describe("On initialization",function()
		
		it("Sets all class variables to default values",function()
			local df = Dataframe()

			assert.are.same(df.dataset,{})
			assert.are.same(df.columns,{})
			assert.are.same(df.column_order,{})
			assert.are.same(df.categorical,{})
			assert.are.same(df.print,{no_rows = 10, max_col_width = 20})
			assert.are.same(df.schema,{})
			assert.is.equal(df.n_rows,0)
		end)

		it("Loads a CSV file if passed in argument",function()
			local df = Dataframe("./data/simple_short.csv")
			assert.are.same(df:shape(),{rows=4, cols=3})
		end)

		it("Loads a table if passed in argument",function()
			local df = Dataframe({
				['first_column']={3,4,5},
				['second_column']={10,11,12}
			})

			assert.are.same(df:get_column("first_column"), {3,4,5})
			assert.are.same(df:get_column("second_column"), {10,11,12})
		end)
	end)

	describe("When using internal functions",function()

		it("Resets all class-variables to default values ",function()
			local df = Dataframe({
				['first_column']={3,4,5},
				['second_column']={10,11,12}
			})

			df:_clean()

			assert.are.same(df.dataset,{})
			assert.are.same(df.columns,{})
			assert.are.same(df.column_order,{})
			assert.are.same(df.categorical,{})
			assert.are.same(df.print,{no_rows = 10, max_col_width = 20})
			assert.are.same(df.schema,{})
			assert.is.equal(df.n_rows,0)
		end)

		it("Copy all meta variables to a new Dataframe object",function()
			local df = Dataframe("./data/simple_short.csv")
			local df2 = Dataframe()

			df:_copy_meta(df2)

			assert.are.same(df2.dataset,{})
			assert.are.same(df2.columns,{})
			assert.is.equal(df2.n_rows,0)

			assert.are.same(df.column_order,df2.column_order)
			assert.are.same(df.categorical,df2.categorical)
			assert.are.same(df.print,df2.print)
			assert.are.same(df.schema,df2.schema)
		end)
	end)

	it("Update the schema",function()
		local a = Dataframe()
		local first = {1,2,3}
		local second = {"2","1","3"}
		local third = {"2","a","3"}
		
		data = {['firstColumn']=first,
				['secondColumn']=second,
				['thirdColumn']=third}
		
		a:load_table{data=data}
		
		assert.is.equal(a.schema["firstColumn"], 'number')
		assert.is.equal(a.schema["secondColumn"], 'number')
		assert.is.equal(a.schema["thirdColumn"], 'string')
	end)

	it("Returns the shape of the Dataframe",function()
		local a = Dataframe("./data/simple_short.csv")

		assert.are.same(a:shape(), {rows = 4, cols = 3})

		a:load_csv{path = "./data/advanced_short.csv",
		verbose = false}
		assert.are.same(a:shape(), {rows = 3, cols = 3})

		a:load_table{data = {test = {1,nil,3}}}
		assert.are.same(a:shape(), {rows = 3, cols = 1})
	end)

	it("Loads a table of two columns", function()
		local a = Dataframe()
		local first = {1,2,3}
		local second = {"a","b","c"}

		a:load_table{data={['firstColumn']=first,
						   ['secondColumn']=second}}

		assert.are.same(a:get_column('firstColumn'), first)
		assert.are.same(a:get_column('secondColumn'), second)
	end)

	it("Cleans column names", function()
		local a = Dataframe()
		local first = {1,2,3}
		local second = {"a","b","c"}

		a:load_table{data={['firstColumn ']=first,
						   [' secondColumn']=second}}

		assert.are.same(a:get_column('firstColumn'), first)
		assert.are.same(a:get_column('secondColumn'), second)
	end)

	it("Removes an entire column", function()
		local a = Dataframe("./data/simple_short.csv")

		a:drop('Col A')
		assert.is_true(not a:has_column('Col A'))
		assert.is_true(a:has_column('Col B'))
		assert.is_true(a:has_column('Col C'))
		assert.are.same(a:shape(), {rows=4, cols=2})-- "The simple_short.csv is 4x3 after drop should be 4x2"
		-- Should cause an error
		--tester:assertError(a:drop('Col A'))

		-- Drop second column
		a:drop('Col B')
		assert.is_true(not a:has_column('Col A'))
		assert.is_true(not a:has_column('Col B'))
		assert.is_true(a:has_column('Col C'))
		assert.are.same(a:shape(), {rows=4, cols=1})-- "The simple_short.csv is 4x3 after drop should be 4x1"

		-- All are dropped
		a:drop('Col C')
		assert.are.same(a.dataset, {})-- "All columns are dropped"
	end)

	it("Adds a column",function()
		local a = Dataframe("./data/simple_short.csv")

		d_col = {0,1,2,3}
		a:add_column('Col D', d_col)
		assert.is_not.equal(a:get_column('Col A'), nil)-- "Col A should be present"
		assert.is_not.equal(a:get_column('Col B'), nil)-- "Col B should be present"
		assert.is_not.equal(a:get_column('Col C'), nil)-- "Col C should be present"
		assert.are.same(a:get_column('Col D'), d_col)-- "Col D isn't the expected value"
		assert.are.same(a:shape(), {rows=4, cols=4})-- "The simple_short.csv is 4x3 after add should be 4x4"
		assert.has.error(function() a:add_column('Col D') end)
		a:add_column('Col E')
		col = a:get_column('Col E')

		for _,v in pairs(col) do
			assert.is_true(isnan(v))
		end
		
		a:add_column('Col F', 1)
		assert.are.same(a:get_column('Col F'), {1,1,1,1})
	end)

	it("Returns a column",function()
		local a = Dataframe("./data/simple_short.csv")

		assert.has.error(function() a:get_column('Col D') end)
		assert.is_not.equal(a:get_column('Col C'), nil)
	end)

	it("Inserts new data",function()
		local a = Dataframe("./data/simple_short.csv")

		a:insert({['Col A']={15},['Col B']={25},['Col C']={35}})
		assert.are.same(a:shape(), {rows=5, cols=3})-- "The simple_short.csv is 4x3 after insert should be 5x3"
	end)

	it("Resets a column",function()
		local a = Dataframe("./data/simple_short.csv")

		a:reset_column('Col C', 555)
		assert.are.same(a:shape(), {rows=4, cols=3})-- "The simple_short.csv is 4x3"
		assert.are.same(a:get_column('Col C'), {555, 555, 555, 555})

		a:reset_column({'Col A', 'Col B'}, 555)
		assert.are.same(a:get_column('Col A'), {555, 555, 555, 555})
		assert.are.same(a:get_column('Col B'), {555, 555, 555, 555})
	end)

	it("Removes a row given an index",function()
		local a = Dataframe("./data/simple_short.csv")

		a:remove_index(1)
		assert.are.same(a:shape(), {rows=3, cols=3})-- "The simple_short.csv is 4x3"
		assert.are.same(a:get_column('Col A'), {2,3,4})

		a:remove_index(1)
		a:remove_index(1)
		a:remove_index(1)
		assert.are.same(a:shape(), {rows=0, cols=3})
	end)

	it("Renames a column", function()
		local a = Dataframe("./data/simple_short.csv")

		a:rename_column("Col A", "Col D")
		assert.is_true(a:has_column("Col D"))
		assert.is_true(not a:has_column("Col A"))
	end)

	it("Counts and fill missing values of a specific column", function()
		local a = Dataframe("./data/advanced_short.csv")

		assert.are.same(a:count_na(), {["Col A"]= 0, ["Col B"]= 0, ["Col C"]=1})
		a:fill_na("Col A", 1)
		assert.are.same(a:count_na(), {["Col A"]= 0, ["Col B"]= 0, ["Col C"]=1})
		a:fill_na("Col C", 1)
		assert.are.same(a:count_na(), {["Col A"]= 0, ["Col B"]= 0, ["Col C"]=0})
		assert.are.same(a:get_column("Col C"), {8, 1, 9})
	end)

	it("Fills all Dataframe's missi g values", function()
		local a = Dataframe("./data/advanced_short.csv")

		a.dataset['Col A'][3] = nil
		
		assert.are.same(a:count_na(), {["Col A"]= 1, ["Col B"]= 0, ["Col C"]=1})
		
		a:fill_all_na(-1)

		assert.are.same(a:count_na(), {["Col A"]= 0, ["Col B"]= 0, ["Col C"]=0})
		assert.are.same(a:get_column('Col A'), {1,2,-1})
	end)

	it("Returns all numerical columns names", function()
		local a = Dataframe("./data/advanced_short.csv")

		assert.are.same(a:get_numerical_colnames(), {'Col A', 'Col C'})
	end)

	it("Exports the Dataframe to a tensor",function()
		local a = Dataframe("./data/advanced_short.csv")

		tnsr = a:to_tensor()
		assert.is.equal(tnsr:size(1),a:shape()["rows"])
		assert.is.equal(tnsr:size(2),a:shape()["cols"]-1)
		sum = 0
		col_no = a:get_column_no('Col A')

		for i=1,tnsr:size(1) do
			sum = math.abs(tnsr[i][col_no] - a:get_column('Col A')[i])
		end
		
		assert.is_true(sum < 10^-5)
	end)

	it("Exports the Dataframe to a CSV file",function()
		local a = Dataframe("./data/simple_short.csv")

		a:to_csv{path = "./data/copy_of_short.csv", verbose = false}
		local b = Dataframe()
		b:load_csv{path = "./data/copy_of_short.csv", verbose = false}

		for k,v in pairs(a.dataset) do
			assert.are.same(a:get_column(k),
			b:get_column(k))
		end

		os.remove("./data/copy_of_short.csv")
	end)

	it("Returns first elements of the dataframe",function()
		local a = Dataframe("./data/simple_short.csv")

		head = a:head(2)
		assert.is.equal(head.n_rows, 2)-- "Self the n_rows isn't updated, is " .. head.n_rows .. " instead of expected 2"
		-- do a manual count
		local no_elmnts = 0
		for k,v in pairs(head.dataset) do
			local l = table.exact_length(v)
			
			if (l > no_elmnts) then
				no_elmnts = l
			end
		end

		assert.is.equal(no_elmnts, 2)-- "Expecting 2 elements got " .. no_elmnts .. " elements when counting manually"

		-- Only 4 rows and thus all should be included
		head = a:head(20)
		assert.is.equal(head.n_rows, a.n_rows)-- "The elements should be identical to the original " .. a.n_rows .. " got instead " .. head.n_rows .. " elements"

		head = a:head()
		assert.is.equal(head.n_rows, a.n_rows)-- "The elements should be identical to the original " .. a.n_rows .. " as the default is < original elements. Got instead " .. head.n_rows .. " elements"
	end)

	it("Returns last elements of the dataframe",function()
		local a = Dataframe("./data/simple_short.csv")

		tail = a:tail(2)
		assert.is.equal(tail.n_rows, 2)-- "Self the n_rows isn't updated, is " .. tail.n_rows .. " instead of expected 2"
		-- Do a manual count
		local no_elmnts = 0
		for k,v in pairs(tail.dataset) do
			local l = table.exact_length(v)
			if (l > no_elmnts) then
				no_elmnts = l
			end
		end
		assert.is.equal(no_elmnts, 2)-- "Should have selected 2 last elements but got " .. no_elmnts .. " when doin a manual count"

		-- Only 4 rows and thus all should be included
		tail = a:tail(20)
		assert.is.equal(tail.n_rows, a.n_rows)-- "Should have selected 20 las elements and returned the original length " .. a.n_rows .. " since there are only 4 rows and not " .. tail.n_rows

		tail = a:tail()
		assert.is.equal(tail.n_rows, a.n_rows)-- "Default selection is bigger than the simple_short, you got " .. tail.n_rows .. " instead of " .. a.n_rows
	end)

	it("Returns all unique values in a column", function()
		local a = Dataframe("./data/advanced_short.csv")

		assert.are.same(a:unique('Col A'), {1,2,3})-- "Failed to match Col A"
		assert.are.same(a:unique('Col B', true), {A=1, B=2})-- "Failed to match Col B"
		assert.are.same(a:unique('Col C', true), {[8]=1, [9]=2})-- "Failed to match Col C"
	end)

	it("Retrieves a value in a column",function()
		local a = Dataframe("./data/simple_short.csv")

		local ret_val = a:where('Col A', 2)
		assert.are.same(ret_val:get_column("Col A"), {2})
		assert.are.same(ret_val:get_column("Col C"), {.1})
		assert.is.equal(torch.type(ret_val), "Dataframe")
		assert.are.same(ret_val:shape(), {rows = 1, cols = 3})

		local ret_val = a:where('Col A', 222222222)
		assert.are.same(ret_val:shape(), {rows = 0, cols = 0})

		a:__init()
		a:load_csv{path = "./data/advanced_short.csv",
		verbose = false}
		ret_val = a:where('Col B', 'B')
		assert.are.same(ret_val:shape(), {rows = 2, cols = 3})
		col_c = ret_val:get_column('Col C')
		assert.is_true(isnan(col_c[1]))
		assert.is.equal(col_c[2], 9)
		assert.are.same(ret_val:get_column('Col A'), {2, 3})
	end)

	it("Updates multiple rows according to a custom condition", function()
		local a = Dataframe("./data/simple_short.csv")

		local start_val = a:get_column('Col B')
		start_val[1] = start_val[1] * 2

		a:update(
			function(s_row) return s_row['Col A'] == 1 end,
			function(upd_row) upd_row['Col B'] = upd_row['Col B'] * 2 return upd_row end
		)
		assert.are.same(a:get_column('Col B'), start_val)

		-- Check a double match
		local b = Dataframe("./data/advanced_short.csv")

		start_val = b:get_column('Col A')
		start_val[2] = start_val[2] * 2
		start_val[3] = start_val[3] * 2
		b:update(
			function(s_row) return s_row['Col B'] == 1 end,
			function(upd_row) upd_row['Col A'] = upd_row['Col A'] * 2 return upd_row end
		)

		assert.are.same(b:get_column('Col A'), start_val)
	end)

	it("Updates a single cell given a column name and an index",function()
		local a = Dataframe("./data/simple_short.csv")

		a:set(1, 'Col A', {['Col A']=99})
		assert.is.equal(a:get_column('Col A')[1], 99)
	end)

	it("Get a single row given an index",function()
		local a = Dataframe("./data/simple_short.csv")

		assert.are.same(a:get_row(1),{
		['Col A']=1,
		['Col B']=.2,
		['Col C']=1000
		})
	end)

	it(" Updates a unique row given an index",function()
		local a = Dataframe("./data/simple_short.csv")

		new = {
		['Col A']=4,
		['Col B']=4,
		['Col C']=4
		}
		a:_update_single_row(1, new)
		assert.are.same(a:get_row(1), new)
	end)
end)