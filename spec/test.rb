class TestClass
  def method
    [1, 2, 3].each_with_object({}) do |num, hash|
      hash[:hi] = if true
        num
      else
        num - 1
      end
    end
  rescue IntermediateDelimiters::Error
    puts 'whoops'
  end
end
