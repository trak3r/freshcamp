# http://opensoul.org/2007/7/18/round-floats-to-the-nearest-x
class Float
  def round(round_to = 1.0)
    return self if 0 == self % round_to
    mod = self % round_to
    rounded = self - mod + round_to #(mod >= round_to/2.0 ? round_to : 0)
    rounded % 1 == 0 ? rounded.to_i : rounded
  end
end
